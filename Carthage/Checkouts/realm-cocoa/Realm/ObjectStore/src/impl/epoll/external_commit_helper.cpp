////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#include "impl/external_commit_helper.hpp"
#include "impl/realm_coordinator.hpp"
#include <realm/util/fifo_helper.hpp>

#include <realm/util/assert.hpp>
#include <realm/db.hpp>

#include <algorithm>
#include <errno.h>
#include <fcntl.h>
#include <sstream>
#include <stdlib.h>
#include <sys/epoll.h>
#include <sys/time.h>
#include <unistd.h>

#ifdef __ANDROID__
#include <android/log.h>
#define ANDROID_LOG __android_log_print
#else
#define ANDROID_LOG(...)
#endif

using namespace realm;
using namespace realm::_impl;

#define LOGE(...) do { \
    fprintf(stderr, __VA_ARGS__); \
    ANDROID_LOG(ANDROID_LOG_ERROR, "REALM", __VA_ARGS__); \
} while (0)

namespace {
// Write a byte to a pipe to notify anyone waiting for data on the pipe
void notify_fd(int fd)
{
    while (true) {
        char c = 0;
        ssize_t ret = write(fd, &c, 1);
        if (ret == 1) {
            break;
        }

        // If the pipe's buffer is full, we need to read some of the old data in
        // it to make space. We don't just read in the code waiting for
        // notifications so that we can notify multiple waiters with a single
        // write.
        if (ret != 0) {
            int err = errno;
            if (err != EAGAIN) {
                throw std::system_error(err, std::system_category());
            }
        }
        std::vector<uint8_t> buff(1024);
        read(fd, buff.data(), buff.size());
    }
}
} // anonymous namespace

class ExternalCommitHelper::DaemonThread {
public:
    DaemonThread();
    ~DaemonThread();

    void add_commit_helper(ExternalCommitHelper* helper);
    // Return true if the m_helper_list is empty after removal.
    void remove_commit_helper(ExternalCommitHelper* helper);

    static DaemonThread& shared();
private:
    void listen();

    // To protect the accessing m_helpers on the daemon thread.
    std::mutex m_mutex;
    std::vector<ExternalCommitHelper*> m_helpers;
    // The listener thread
    std::thread m_thread;
    // File descriptor for epoll
    FdHolder m_epoll_fd;
    // The two ends of an anonymous pipe used to notify the kqueue() thread that it should be shut down.
    FdHolder m_shutdown_read_fd;
    FdHolder m_shutdown_write_fd;
    // Daemon thread id. For checking unexpected dead locks.
    std::thread::id m_thread_id;
};


void ExternalCommitHelper::FdHolder::close()
{
    if (m_fd != -1) {
        ::close(m_fd);
    }
    m_fd = -1;
}

ExternalCommitHelper::ExternalCommitHelper(RealmCoordinator& parent)
: m_parent(parent)
{
    std::string path;
    std::string temp_dir = util::normalize_dir(parent.get_config().fifo_files_fallback_path);
    std::string sys_temp_dir = util::normalize_dir(DBOptions::get_sys_tmp_dir());

    // Object Store needs to create a named pipe in order to coordinate notifications.
    // This can be a problem on some file systems (e.g. FAT32) or due to security policies in SELinux. Most commonly
    // it is a problem when saving Realms on external storage: https://stackoverflow.com/questions/2740321/how-to-create-named-pipe-mkfifo-in-android
    //
    // For this reason we attempt to create this file in a temporary location known to be safe to write these files.
    //
    // In order of priority we attempt to write the file in the following locations:
    //  1) Next to the Realm file itself
    //  2) A location defined by `Realm::Config::fifo_files_fallback_path`
    //  3) A location defined by `DBOptions::set_sys_tmp_dir()`
    //
    // Core has a similar policy for its named pipes.
    //
    // Also see https://github.com/realm/realm-java/issues/3140
    // Note that hash collisions are okay here because they just result in doing extra work instead of resulting
    // in correctness problems.

    path = parent.get_path() + ".note";
    bool fifo_created = util::try_create_fifo(path);
    if (!fifo_created && !temp_dir.empty()) {
        path = util::format("%1realm_%2.note", temp_dir, std::hash<std::string>()(parent.get_path()));
        fifo_created = util::try_create_fifo(path);
    }
    if (!fifo_created && !sys_temp_dir.empty()) {
        path = util::format("%1realm_%2.note", sys_temp_dir, std::hash<std::string>()(parent.get_path()));
        util::create_fifo(path);
    }

    m_notify_fd = open(path.c_str(), O_RDWR);
    if (m_notify_fd == -1) {
        throw std::system_error(errno, std::system_category());
    }

    // Make writing to the pipe return -1 when the pipe's buffer is full
    // rather than blocking until there's space available
    int ret = fcntl(m_notify_fd, F_SETFL, O_NONBLOCK);
    if (ret == -1) {
        throw std::system_error(errno, std::system_category());
    }

    // Lock is inside add_commit_helper.
    DaemonThread::shared().add_commit_helper(this);
}

ExternalCommitHelper::~ExternalCommitHelper()
{
    DaemonThread::shared().remove_commit_helper(this);
}

ExternalCommitHelper::DaemonThread::DaemonThread()
{
    m_epoll_fd = epoll_create(1);
    if (m_epoll_fd == -1) {
        throw std::system_error(errno, std::system_category());
    }

    // Create the anonymous pipe
    int pipe_fd[2];
    int ret = pipe(pipe_fd);
    if (ret == -1) {
        throw std::system_error(errno, std::system_category());
    }

    m_shutdown_read_fd = pipe_fd[0];
    m_shutdown_write_fd = pipe_fd[1];

    epoll_event event{};
    event.events = EPOLLIN;
    event.data.fd = m_shutdown_read_fd;
    ret = epoll_ctl(m_epoll_fd, EPOLL_CTL_ADD, m_shutdown_read_fd, &event);
    if (ret != 0) {
        int err = errno;
        throw std::system_error(err, std::system_category());
    }

    m_thread = std::thread([=] {
        try {
            listen();
        }
        catch (std::exception const& e) {
            LOGE("uncaught exception in notifier thread: %s: %s\n", typeid(e).name(), e.what());
            throw;
        }
        catch (...) {
            LOGE("uncaught exception in notifier thread\n");
            throw;
        }
    });
    m_thread_id = m_thread.get_id();
}

ExternalCommitHelper::DaemonThread::~DaemonThread()
{
    notify_fd(m_shutdown_write_fd);
    m_thread.join(); // Wait for the thread to exit
}

ExternalCommitHelper::DaemonThread& ExternalCommitHelper::DaemonThread::shared()
{
    static DaemonThread daemon_thread;
    return daemon_thread;
}

void ExternalCommitHelper::DaemonThread::add_commit_helper(ExternalCommitHelper* helper)
{
    // Called in the deamon thread loop, dead lock will happen.
    REALM_ASSERT(std::this_thread::get_id() != m_thread_id);

    std::lock_guard<std::mutex> lock(m_mutex);

    m_helpers.push_back(helper);

    epoll_event event{};
    event.events = EPOLLIN | EPOLLET;
    event.data.fd = helper->m_notify_fd;
    int ret = epoll_ctl(m_epoll_fd, EPOLL_CTL_ADD, helper->m_notify_fd, &event);
    if (ret != 0) {
        int err = errno;
        throw std::system_error(err, std::system_category());
    }
}

void ExternalCommitHelper::DaemonThread::remove_commit_helper(ExternalCommitHelper* helper)
{
    // Called in the deamon thread loop, dead lock will happen.
    REALM_ASSERT(std::this_thread::get_id() != m_thread_id);

    std::lock_guard<std::mutex> lock(m_mutex);

    m_helpers.erase(std::remove(m_helpers.begin(), m_helpers.end(), helper), m_helpers.end());

    // In kernel versions before 2.6.9, the EPOLL_CTL_DEL operation required a non-NULL pointer in event, even
    // though this argument is ignored. See man page of epoll_ctl.
    epoll_event event{};
    epoll_ctl(m_epoll_fd, EPOLL_CTL_DEL, helper->m_notify_fd, &event);
}

void ExternalCommitHelper::DaemonThread::listen()
{
    pthread_setname_np(pthread_self(), "Realm notification listener");

    int ret;

    while (true) {
        epoll_event ev{};
        ret = epoll_wait(m_epoll_fd, &ev, 1, -1);

        if (ret == -1 && errno == EINTR) {
            // Interrupted system call, try again.
            continue;
        }

        if (ret == -1) {
            int err = errno;
            throw std::system_error(err, std::system_category());
        }
        if (ret == 0) {
            // Spurious wakeup; just wait again
            continue;
        }

        if (ev.data.u32 == (uint32_t)m_shutdown_read_fd) {
            return;
        }

        {
            std::lock_guard<std::mutex> lock(m_mutex);
            for (auto helper : m_helpers) {
                if (ev.data.u32 == (uint32_t)helper->m_notify_fd) {
                    helper->m_parent.on_change();
                }
            }
        }
    }
}

void ExternalCommitHelper::notify_others()
{
    notify_fd(m_notify_fd);
}
