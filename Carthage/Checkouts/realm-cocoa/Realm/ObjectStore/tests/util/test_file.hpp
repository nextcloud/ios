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

#ifndef REALM_TEST_UTIL_TEST_FILE_HPP
#define REALM_TEST_UTIL_TEST_FILE_HPP

#include "shared_realm.hpp"
#include "util/tagged_bool.hpp"

#include <realm/util/logger.hpp>
#include <realm/util/optional.hpp>

#include <thread>

#if REALM_ENABLE_SYNC
#include "sync/sync_config.hpp"

#include <realm/sync/client.hpp>
#include <realm/sync/server.hpp>

// {"identity":"test", "access": ["download", "upload"]}
static const std::string s_test_token = "eyJpZGVudGl0eSI6InRlc3QiLCAiYWNjZXNzIjogWyJkb3dubG9hZCIsICJ1cGxvYWQiXX0=";
#endif // REALM_ENABLE_SYNC

namespace realm {
class Schema;
enum class SyncSessionStopPolicy;
struct DBOptions;
struct SyncConfig;
}

class JoiningThread {
public:
    template<typename... Args>
    JoiningThread(Args&&... args) : m_thread(std::forward<Args>(args)...) { }
    ~JoiningThread() { if (m_thread.joinable()) m_thread.join(); }
    void join() { m_thread.join(); }

private:
    std::thread m_thread;
};


struct TestFile : realm::Realm::Config {
    TestFile();
    ~TestFile();

    // The file should outlive the object, ie. should not be deleted in destructor
    void persist()
    {
        m_persist = true;
    }

    realm::DBOptions options() const;

private:
    bool m_persist = false;
};

struct InMemoryTestFile : TestFile {
    InMemoryTestFile();
};

void advance_and_notify(realm::Realm& realm);
void on_change_but_no_notify(realm::Realm& realm);

#if REALM_ENABLE_SYNC

#define TEST_ENABLE_SYNC_LOGGING 0 // change to 1 to enable logging

struct TestLogger : realm::util::Logger::LevelThreshold, realm::util::Logger {
    void do_log(realm::util::Logger::Level, std::string) override {}
    Level get() const noexcept override { return Level::off; }
    TestLogger() : Logger::LevelThreshold(), Logger(static_cast<Logger::LevelThreshold&>(*this)) { }
};

using StartImmediately = realm::util::TaggedBool<class StartImmediatelyTag>;

class SyncServer : private realm::sync::Clock {
public:
    SyncServer(StartImmediately start_immediately=true, std::string local_dir = "");
    ~SyncServer();

    void start();
    void stop();

    std::string url_for_realm(realm::StringData realm_name) const;
    std::string base_url() const { return m_url; }
    std::string local_root_dir() const { return m_local_root_dir; }

    template <class R, class P>
    void advance_clock(std::chrono::duration<R, P> duration = std::chrono::seconds(1)) noexcept
    {
        m_now += std::chrono::duration_cast<time_point::duration>(duration).count();
    }

private:
    std::string m_local_root_dir;
    std::unique_ptr<realm::util::Logger> m_logger;
    realm::sync::Server m_server;
    std::thread m_thread;
    std::string m_url;
    std::atomic<time_point::rep> m_now{0};

    time_point now() const noexcept override
    {
        return time_point{time_point::duration{m_now}};
    }
};

struct SyncTestFile : TestFile {
    template<typename BindHandler, typename ErrorHandler>
    SyncTestFile(const realm::SyncConfig& sync_config, 
        realm::SyncSessionStopPolicy stop_policy, 
        BindHandler&& bind_handler, 
        ErrorHandler&& error_handler)
    {
        this->sync_config = std::make_shared<realm::SyncConfig>(sync_config);
        this->sync_config->stop_policy = stop_policy;
        this->sync_config->bind_session_handler = std::forward<BindHandler>(bind_handler);
        this->sync_config->error_handler = std::forward<ErrorHandler>(error_handler);
        schema_mode = realm::SchemaMode::Additive;
    }

    SyncTestFile(SyncServer& server, std::string name="", bool is_partial=false,
                 std::string user_name="test");
};

struct TestSyncManager {
    TestSyncManager(std::string const& base_path="", realm::SyncManager::MetadataMode = realm::SyncManager::MetadataMode::NoEncryption);
    ~TestSyncManager();
    static void configure(std::string const& base_path, realm::SyncManager::MetadataMode);
};

void wait_for_upload(realm::Realm& realm);
void wait_for_download(realm::Realm& realm);

#endif // REALM_ENABLE_SYNC

#endif
