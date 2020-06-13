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

#include "catch2/catch.hpp"

#include "util/index_helpers.hpp"
#include "util/test_file.hpp"
#include "util/test_utils.hpp"

#include "impl/collection_notifier.hpp"
#include "impl/realm_coordinator.hpp"
#include "impl/transact_log_handler.hpp"
#include "binding_context.hpp"
#include "property.hpp"
#include "object_schema.hpp"
#include "schema.hpp"

#include <realm/db.hpp>
#include <realm/history.hpp>

using namespace realm;

class CaptureHelper {
public:
    CaptureHelper(TransactionRef group, SharedRealm const& r, LnkLst& lv, TableKey table_key)
    : m_realm(r)
    , m_group(group)
    , m_list(lv)
    , m_table_key(table_key)
    {
        m_realm->begin_transaction();

        m_initial.reserve(lv.size());
        for (size_t i = 0; i < lv.size(); ++i)
            m_initial.push_back(lv.ObjList::get_key(i));
    }

    CollectionChangeSet finish() {
        m_realm->commit_transaction();

        _impl::CollectionChangeBuilder c;
        _impl::TransactionChangeInfo info{};
        info.tables[m_table_key.value];
        info.lists.push_back({m_table_key, m_list.ConstLstBase::get_key().value, m_list.get_col_key().value, &c});
        _impl::transaction::advance(*m_group, info);

        if (info.lists.empty()) {
            REQUIRE(!m_list.is_attached());
            return {};
        }

        validate(c);
        return std::move(c);
    }

    explicit operator bool() const { return m_realm->is_in_transaction(); }

private:
    SharedRealm m_realm;
    TransactionRef m_group;

    LnkLst& m_list;
    std::vector<ObjKey> m_initial;
    TableKey m_table_key;

    void validate(CollectionChangeSet const& info)
    {
        info.insertions.verify();
        info.deletions.verify();
        info.modifications.verify();

        std::vector<ObjKey> move_sources;
        for (auto const& move : info.moves)
            move_sources.push_back(m_initial[move.from]);

        // Apply the changes from the transaction log to our copy of the
        // initial, using UITableView's batching rules (i.e. delete, then
        // insert, then update)
        auto it = util::make_reverse_iterator(info.deletions.end());
        auto end = util::make_reverse_iterator(info.deletions.begin());
        for (; it != end; ++it) {
            m_initial.erase(m_initial.begin() + it->first, m_initial.begin() + it->second);
        }

        m_list.size();
        for (auto const& range : info.insertions) {
            for (auto i = range.first; i < range.second; ++i)
                m_initial.insert(m_initial.begin() + i, m_list.ObjList::get_key(i));
        }

        for (auto const& range : info.modifications) {
            for (auto i = range.first; i < range.second; ++i)
                m_initial[i] = m_list.ObjList::get_key(i);
        }

        REQUIRE(m_list.is_attached());

        // and make sure we end up with the same end result
        if (m_initial.size() != m_list.size()) {
            std::cout << "Error " << m_list.size() << std::endl;
        }
        REQUIRE(m_initial.size() == m_list.size());
        for (size_t i = 0; i < m_initial.size(); ++i)
            CHECK(m_initial[i] == m_list.ObjList::get_key(i));

        // Verify that everything marked as a move actually is one
        for (size_t i = 0; i < move_sources.size(); ++i) {
            if (!info.modifications.contains(info.moves[i].to)) {
                CHECK(m_list.ObjList::get_key(info.moves[i].to) == move_sources[i]);
            }
        }
    }
};

struct ArrayChange {
    BindingContext::ColumnInfo::Kind kind;
    IndexSet indices;
};

static bool operator==(ArrayChange const& a, ArrayChange const& b)
{
    return a.kind == b.kind
        && std::equal(a.indices.as_indexes().begin(), a.indices.as_indexes().end(),
                      b.indices.as_indexes().begin(), b.indices.as_indexes().end());
}

namespace Catch {
template<>
struct StringMaker<ArrayChange> {
    static std::string convert(ArrayChange const& c)
    {
        std::stringstream ss;
        switch (c.kind) {
            case BindingContext::ColumnInfo::Kind::Insert: ss << "Insert{"; break;
            case BindingContext::ColumnInfo::Kind::Remove: ss << "Remove{"; break;
            case BindingContext::ColumnInfo::Kind::Set: ss << "Set{"; break;
            case BindingContext::ColumnInfo::Kind::SetAll: return "SetAll";
            case BindingContext::ColumnInfo::Kind::None: return "None";
        }
        for (auto& range : c.indices)
            ss << range.first << "-" << range.second << ", ";
        auto str = ss.str();
        str.pop_back();
        str.back() = '}';
        return str;
    }
};
} // namespace Catch

class KVOContext : public BindingContext {
public:
    KVOContext(std::initializer_list<Obj> objects)
    {
        m_result.reserve(objects.size());
        for (auto& obj : objects) {
            m_result.push_back(ObserverState{obj.get_table()->get_key(),
                obj.get_key().value, (void *)(uintptr_t)m_result.size()});
        }
    }

    bool modified(size_t index, ColKey col_key) const noexcept
    {
        auto it = std::find_if(begin(m_result), end(m_result),
                               [=](auto&& change) { return (void *)(uintptr_t)index == change.info; });
        if (it == m_result.end())
            return false;
        auto col = it->changes.find(col_key.value);
        return col != it->changes.end() && col->second.kind != BindingContext::ColumnInfo::Kind::None;
    }

    bool invalidated(size_t index) const noexcept
    {
        return std::find(begin(m_invalidated), end(m_invalidated), (void *)(uintptr_t)index) != end(m_invalidated);
    }

    ArrayChange array_change(size_t index, ColKey col_key) const noexcept
    {
        auto& changes = m_result[index].changes;
        auto col = changes.find(col_key.value);
        return col == changes.end()
            ? ArrayChange{ColumnInfo::Kind::None, {}}
            : ArrayChange{col->second.kind, col->second.indices};
    }

private:
    std::vector<ObserverState> m_result;
    std::vector<void*> m_invalidated;

    std::vector<ObserverState> get_observed_rows() override
    {
        return m_result;
    }

    void did_change(std::vector<ObserverState> const& observers,
                    std::vector<void*> const& invalidated, bool) override
    {
        m_invalidated = invalidated;
        m_result = observers;
    }
};

TEST_CASE("Transaction log parsing: schema change validation") {
    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    config.schema_mode = SchemaMode::Additive;
    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"table", {
            {"unindexed", PropertyType::Int},
            {"indexed", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}}
        }},
    });
    r->read_group();

    auto history = make_in_realm_history(config.path);
    auto db = DB::create(*history, config.options());

    SECTION("adding a table is allowed") {
        auto wt = db->start_write();
        TableRef table = wt->add_table("new table");
        table->add_column(type_String, "new col");
        wt->commit();

        REQUIRE_NOTHROW(r->refresh());
    }

    SECTION("adding a column at the end of an existing table is allowed") {
        auto wt = db->start_write();
        TableRef table = wt->get_table("class_table");
        table->add_column(type_String, "new col");
        wt->commit();

        REQUIRE_NOTHROW(r->refresh());
    }

    SECTION("removing a column is not allowed") {
        auto wt = db->start_write();
        TableRef table = wt->get_table("class_table");
        table->remove_column(table->get_column_key("indexed"));
        wt->commit();

        REQUIRE_THROWS(r->refresh());
    }

    SECTION("removing a table is not allowed") {
        auto wt = db->start_write();
        wt->remove_table("class_table");
        wt->commit();

        REQUIRE_THROWS(r->refresh());
    }
}

TEST_CASE("Transaction log parsing: changeset calcuation") {
    InMemoryTestFile config;
    config.automatic_change_notifications = false;

    SECTION("table change information") {
        auto r = Realm::get_shared_realm(config);
        r->update_schema({
            {"table", {
                {"pk", PropertyType::Int, Property::IsPrimary{true}},
                {"value", PropertyType::Int}
            }},
        });

        auto& table = *r->read_group().get_table("class_table");
        auto table_key = table.get_key().value;
        auto cols = table.get_column_keys();

        r->begin_transaction();
        std::vector<ObjKey> objects;
        table.create_objects(10, objects);
        for (int i = 0; i < 10; ++i)
            table.get_object(objects[i]).set_all(i, i);
        r->commit_transaction();

        auto coordinator = _impl::RealmCoordinator::get_coordinator(config.path);
        using TableKeyType = decltype(TableKey::value);
        auto track_changes = [&](std::vector<TableKeyType> tables_needed, auto&& f) {
            auto sg = coordinator->begin_read();

            r->begin_transaction();
            f();
            r->commit_transaction();

            _impl::TransactionChangeInfo info{};
            for (auto table : tables_needed)
                info.tables[table];
            _impl::transaction::advance(static_cast<Transaction&>(*sg), info);
            return info;
        };

        SECTION("modifying a row marks it as modified") {
            auto info = track_changes({table_key}, [&] {
                table.get_object(objects[1]).set(cols[1], 2);
            });
            REQUIRE(info.tables.size() == 1);
            REQUIRE(info.tables[table_key].modifications_size() == 1);
            REQUIRE(info.tables[table_key].modifications_contains(1));
        }

        SECTION("modifications to untracked tables are ignored") {
            auto info = track_changes({}, [&] {
                table.get_object(objects[1]).set(cols[1], 2);
            });
            REQUIRE(info.tables.empty());
        }

        SECTION("new row additions are reported") {
            auto info = track_changes({table_key}, [&] {
                table.create_object();
                table.create_object();
            });
            REQUIRE(info.tables.size() == 1);
            REQUIRE(info.tables[table_key].insertions_size() == 2);
            REQUIRE(info.tables[table_key].insertions_contains(10));
            REQUIRE(info.tables[table_key].insertions_contains(11));
        }

        SECTION("deleting newly added rows makes them not be reported") {
            auto info = track_changes({table_key}, [&] {
                table.create_object();
                table.remove_object(table.create_object().get_key());
            });
            REQUIRE(info.tables.size() == 1);
            REQUIRE(info.tables[table_key].insertions_size() == 1);
            REQUIRE(info.tables[table_key].insertions_contains(10));
            REQUIRE(info.tables[table_key].deletions_empty());
        }

        SECTION("modifying newly added rows does not report it as a modification") {
            auto info = track_changes({table_key}, [&] {
                table.create_object().set_all(10, 0);
            });
            REQUIRE(info.tables.size() == 1);
            REQUIRE(info.tables[table_key].insertions_size() == 1);
            REQUIRE(info.tables[table_key].insertions_contains(10));
            REQUIRE(info.tables[table_key].modifications_size() == 0);
            REQUIRE(!info.tables[table_key].modifications_contains(10));
            REQUIRE(info.tables[table_key].deletions_empty());
        }

        SECTION("remove_object() does not shift rows") {
            auto info = track_changes({table_key}, [&] {
                table.remove_object(objects[2]);
                table.remove_object(objects[3]);
            });
            REQUIRE(info.tables.size() == 1);
            REQUIRE(info.tables[table_key].deletions_size() == 2);
            REQUIRE(info.tables[table_key].deletions_contains(2));
            REQUIRE(info.tables[table_key].deletions_contains(3));
            REQUIRE(info.tables[table_key].insertions_empty());
            REQUIRE(info.tables[table_key].modifications_empty());
        }

        SECTION("SetDefault does not mark a row as modified") {
            auto info = track_changes({table_key}, [&] {
                bool is_default = true;
                table.get_object(objects[0]).set(cols[0], 1, is_default);
            });
            REQUIRE(info.tables.empty());
        }
    }

    SECTION("LinkView change information") {
        auto r = Realm::get_shared_realm(config);
        r->update_schema({
            {"origin", {
                {"array", PropertyType::Array|PropertyType::Object, "target"}
            }},
            {"target", {
                {"value", PropertyType::Int}
            }},
        });

        auto origin = r->read_group().get_table("class_origin");
        auto target = r->read_group().get_table("class_target");

        r->begin_transaction();

        LnkLst lv = origin->create_object().get_linklist("array");
        std::vector<ObjKey> target_keys;
        for (int i = 0; i < 10; ++i) {
            target_keys.push_back(target->create_object().set_all(i).get_key());
            lv.add(target_keys.back());
        }

        r->commit_transaction();

        auto coordinator = _impl::RealmCoordinator::get_coordinator(config.path);
#define VALIDATE_CHANGES(out) \
    for (CaptureHelper helper(std::static_pointer_cast<Transaction>(coordinator->begin_read()), r, lv, origin->get_key()); \
         helper; out = helper.finish())

        CollectionChangeSet changes;
        SECTION("single change type") {
            SECTION("add single") {
                VALIDATE_CHANGES(changes) {
                    lv.add(target_keys[0]);
                }
                REQUIRE_INDICES(changes.insertions, 10);
            }
            SECTION("add multiple") {
                VALIDATE_CHANGES(changes) {
                    lv.add(target_keys[0]);
                    lv.add(target_keys[0]);
                }
                REQUIRE_INDICES(changes.insertions, 10, 11);
            }

            SECTION("erase single") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.deletions, 5);
            }
            SECTION("erase contiguous forward") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(5);
                    lv.remove(5);
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.deletions, 5, 6, 7);
            }
            SECTION("erase contiguous reverse") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(7);
                    lv.remove(6);
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.deletions, 5, 6, 7);
            }
            SECTION("erase contiguous mixed") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(5);
                    lv.remove(6);
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.deletions, 5, 6, 7);
            }
            SECTION("erase scattered forward") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(3);
                    lv.remove(4);
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.deletions, 3, 5, 7);
            }
            SECTION("erase scattered backwards") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(7);
                    lv.remove(5);
                    lv.remove(3);
                }
                REQUIRE_INDICES(changes.deletions, 3, 5, 7);
            }
            SECTION("erase scattered mixed") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(3);
                    lv.remove(6);
                    lv.remove(4);
                }
                REQUIRE_INDICES(changes.deletions, 3, 5, 7);
            }

            SECTION("set single") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                }
                REQUIRE_INDICES(changes.modifications, 5);
            }
            SECTION("set contiguous") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.set(6, target_keys[0]);
                    lv.set(7, target_keys[0]);
                }
                REQUIRE_INDICES(changes.modifications, 5, 6, 7);
            }
            SECTION("set scattered") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.set(7, target_keys[0]);
                    lv.set(9, target_keys[0]);
                }
                REQUIRE_INDICES(changes.modifications, 5, 7, 9);
            }
            SECTION("set redundant") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.set(5, target_keys[0]);
                    lv.set(5, target_keys[0]);
                }
                REQUIRE_INDICES(changes.modifications, 5);
            }

            SECTION("clear") {
                VALIDATE_CHANGES(changes) {
                    lv.clear();
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
            }

            SECTION("move backward") {
                VALIDATE_CHANGES(changes) {
                    lv.move(5, 3);
                }
                REQUIRE_MOVES(changes, {5, 3});
            }

            SECTION("move forward") {
                VALIDATE_CHANGES(changes) {
                    lv.move(1, 3);
                }
                REQUIRE_MOVES(changes, {1, 3});
            }

            SECTION("chained moves") {
                VALIDATE_CHANGES(changes) {
                    lv.move(1, 3);
                    lv.move(3, 5);
                }
                REQUIRE_MOVES(changes, {1, 5});
            }

            SECTION("backwards chained moves") {
                VALIDATE_CHANGES(changes) {
                    lv.move(5, 3);
                    lv.move(3, 1);
                }
                REQUIRE_MOVES(changes, {5, 1});
            }

            SECTION("moves shifting other moves") {
                VALIDATE_CHANGES(changes) {
                    lv.move(1, 5);
                    lv.move(2, 7);
                }
                REQUIRE_MOVES(changes, {1, 4}, {3, 7});

                VALIDATE_CHANGES(changes) {
                    lv.move(1, 5);
                    lv.move(7, 0);
                }
                REQUIRE_MOVES(changes, {1, 6}, {7, 0});
            }

            SECTION("move to current location is a no-op") {
                VALIDATE_CHANGES(changes) {
                    lv.move(5, 5);
                }
                REQUIRE(changes.insertions.empty());
                REQUIRE(changes.deletions.empty());
                REQUIRE(changes.moves.empty());
            }

            SECTION("delete a target row") {
                VALIDATE_CHANGES(changes) {
                    target->get_object(5).remove();
                }
                REQUIRE_INDICES(changes.deletions, 5);
            }

            SECTION("delete all target rows") {
                VALIDATE_CHANGES(changes) {
                    lv.remove_all_target_rows();
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
            }

            SECTION("clear target table") {
                VALIDATE_CHANGES(changes) {
                    target->clear();
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
            }

            SECTION("swap()") {
                VALIDATE_CHANGES(changes) {
                    lv.swap(3, 5);
                }
                REQUIRE_MOVES(changes, {3, 5}, {5, 3});
            }
        }

        SECTION("mixed change types") {
            SECTION("set -> insert") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.insert(5, target_keys[0]);
                }
                REQUIRE_INDICES(changes.insertions, 5);
                REQUIRE_INDICES(changes.modifications, 6);

                VALIDATE_CHANGES(changes) {
                    lv.set(4, target_keys[0]);
                    lv.insert(5, target_keys[0]);
                }
                REQUIRE_INDICES(changes.insertions, 5);
                REQUIRE_INDICES(changes.modifications, 4);
            }
            SECTION("insert -> set") {
                VALIDATE_CHANGES(changes) {
                    lv.insert(5, target_keys[0]);
                    lv.set(5, target_keys[1]);
                }
                REQUIRE_INDICES(changes.insertions, 5);
                REQUIRE_INDICES(changes.modifications, 5);

                VALIDATE_CHANGES(changes) {
                    lv.insert(5, target_keys[0]);
                    lv.set(6, target_keys[1]);
                }
                REQUIRE_INDICES(changes.insertions, 5);
                REQUIRE_INDICES(changes.modifications, 6);

                VALIDATE_CHANGES(changes) {
                    lv.insert(6, target_keys[0]);
                    lv.set(5, target_keys[1]);
                }
                REQUIRE_INDICES(changes.insertions, 6);
                REQUIRE_INDICES(changes.modifications, 5);
            }

            SECTION("set -> erase") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.deletions, 5);
                REQUIRE(changes.modifications.empty());

                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.remove(4);
                }
                REQUIRE_INDICES(changes.deletions, 4);
                REQUIRE_INDICES(changes.modifications, 4);

                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[0]);
                    lv.remove(4);
                    lv.remove(4);
                }
                REQUIRE_INDICES(changes.deletions, 4, 5);
                REQUIRE(changes.modifications.empty());
            }

            SECTION("erase -> set") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(5);
                    lv.set(5, target_keys[0]);
                }
                REQUIRE_INDICES(changes.deletions, 5);
                REQUIRE_INDICES(changes.modifications, 5);
            }

            SECTION("insert -> clear") {
                VALIDATE_CHANGES(changes) {
                    lv.add(target_keys[0]);
                    lv.clear();
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
                REQUIRE(changes.insertions.empty());
            }

            SECTION("set -> clear") {
                VALIDATE_CHANGES(changes) {
                    lv.set(0, target_keys[5]);
                    lv.clear();
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
                REQUIRE(changes.modifications.empty());
            }

            SECTION("clear -> insert") {
                VALIDATE_CHANGES(changes) {
                    lv.clear();
                    lv.add(target_keys[0]);
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
                REQUIRE_INDICES(changes.insertions, 0);
            }

            SECTION("insert -> delete") {
                VALIDATE_CHANGES(changes) {
                    lv.add(target_keys[0]);
                    lv.remove(10);
                }
                REQUIRE(changes.insertions.empty());
                REQUIRE(changes.deletions.empty());

                VALIDATE_CHANGES(changes) {
                    lv.add(target_keys[0]);
                    lv.remove(9);
                }
                REQUIRE_INDICES(changes.deletions, 9);
                REQUIRE_INDICES(changes.insertions, 9);

                VALIDATE_CHANGES(changes) {
                    lv.insert(1, target_keys[1]);
                    lv.insert(3, target_keys[3]);
                    lv.insert(5, target_keys[5]);
                    lv.remove(6);
                    lv.remove(4);
                    lv.remove(2);
                }
                REQUIRE_INDICES(changes.deletions, 1, 2, 3);
                REQUIRE_INDICES(changes.insertions, 1, 2, 3);

                VALIDATE_CHANGES(changes) {
                    lv.insert(1, target_keys[1]);
                    lv.insert(3, target_keys[3]);
                    lv.insert(5, target_keys[5]);
                    lv.remove(2);
                    lv.remove(3);
                    lv.remove(4);
                }
                REQUIRE_INDICES(changes.deletions, 1, 2, 3);
                REQUIRE_INDICES(changes.insertions, 1, 2, 3);
            }

            SECTION("delete -> insert") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(9);
                    lv.add(target_keys[0]);
                }
                REQUIRE_INDICES(changes.deletions, 9);
                REQUIRE_INDICES(changes.insertions, 9);
            }

            SECTION("interleaved delete and insert") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(9);
                    lv.remove(7);
                    lv.remove(5);
                    lv.remove(3);
                    lv.remove(1);

                    lv.insert(4, target_keys[9]);
                    lv.insert(3, target_keys[7]);
                    lv.insert(2, target_keys[5]);
                    lv.insert(1, target_keys[3]);
                    lv.insert(0, target_keys[1]);

                    lv.remove(9);
                    lv.remove(7);
                    lv.remove(5);
                    lv.remove(3);
                    lv.remove(1);
                }

                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
                REQUIRE_INDICES(changes.insertions, 0, 1, 2, 3, 4);
            }

            SECTION("move after set is just insert+delete") {
                VALIDATE_CHANGES(changes) {
                    lv.set(5, target_keys[6]);
                    lv.move(5, 0);
                }

                REQUIRE_INDICES(changes.deletions, 5);
                REQUIRE_INDICES(changes.insertions, 0);
                REQUIRE_MOVES(changes, {5, 0});
            }

            SECTION("set after move is just insert+delete") {
                VALIDATE_CHANGES(changes) {
                    lv.move(5, 0);
                    lv.set(0, target_keys[6]);
                }

                REQUIRE_INDICES(changes.deletions, 5);
                REQUIRE_INDICES(changes.insertions, 0);
                REQUIRE_MOVES(changes, {5, 0});
            }

            SECTION("delete after move removes original row") {
                VALIDATE_CHANGES(changes) {
                    lv.move(5, 0);
                    lv.remove(0);
                }

                REQUIRE_INDICES(changes.deletions, 5);
                REQUIRE(changes.moves.empty());
            }

            SECTION("moving newly inserted row just changes reported index of insert") {
                VALIDATE_CHANGES(changes) {
                    lv.move(5, 0);
                    lv.remove(0);
                }

                REQUIRE_INDICES(changes.deletions, 5);
                REQUIRE(changes.moves.empty());
            }

            SECTION("moves shift insertions/changes like any other insertion") {
                VALIDATE_CHANGES(changes) {
                    lv.insert(5, target_keys[5]);
                    lv.set(6, target_keys[6]);
                    lv.move(7, 4);
                }
                REQUIRE_INDICES(changes.deletions, 6);
                REQUIRE_INDICES(changes.insertions, 4, 6);
                REQUIRE_INDICES(changes.modifications, 7);
                REQUIRE_MOVES(changes, {6, 4});
            }

            SECTION("clear after delete") {
                VALIDATE_CHANGES(changes) {
                    lv.remove(5);
                    lv.clear();
                }
                REQUIRE_INDICES(changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
            }

            SECTION("erase before previous move target") {
                VALIDATE_CHANGES(changes) {
                    lv.move(2, 8);
                    lv.remove(5);
                }
                REQUIRE_INDICES(changes.insertions, 7);
                REQUIRE_INDICES(changes.deletions, 2, 6);
                REQUIRE_MOVES(changes, {2, 7});
            }

            SECTION("insert after move updates move destination") {
                VALIDATE_CHANGES(changes) {
                    lv.move(2, 8);
                    lv.insert(5, target_keys[5]);
                }
                REQUIRE_MOVES(changes, {2, 9});
            }
        }

        SECTION("deleting the linkview") {
            SECTION("directly") {
                VALIDATE_CHANGES(changes) {
                    origin->get_object(0).remove();
                }
                REQUIRE(!lv.is_attached());
                REQUIRE(changes.insertions.empty());
                REQUIRE(changes.deletions.empty());
                REQUIRE(changes.modifications.empty());
            }

            SECTION("table clear") {
                VALIDATE_CHANGES(changes) {
                    origin->clear();
                }
                REQUIRE(!lv.is_attached());
                REQUIRE(changes.insertions.empty());
                REQUIRE(changes.deletions.empty());
                REQUIRE(changes.modifications.empty());
            }

            SECTION("delete a different lv") {
                r->begin_transaction();
                auto new_obj = origin->create_object();
                r->commit_transaction();

                VALIDATE_CHANGES(changes) {
                    new_obj.remove();
                }
                REQUIRE(changes.insertions.empty());
                REQUIRE(changes.deletions.empty());
                REQUIRE(changes.modifications.empty());
            }
        }

        SECTION("modifying a different linkview should not produce notifications") {
            r->begin_transaction();
            auto lv2 = origin->create_object().get_linklist("array");
            lv2.add(target_keys[5]);
            r->commit_transaction();

            VALIDATE_CHANGES(changes) {
                lv2.add(target_keys[1]);
                lv2.add(target_keys[2]);
                lv2.remove(0);
                lv2.set(0, target_keys[6]);
                lv2.move(1, 0);
                lv2.swap(0, 1);
                lv2.clear();
                lv2.add(target_keys[1]);
            }

            REQUIRE(changes.insertions.empty());
            REQUIRE(changes.deletions.empty());
            REQUIRE(changes.modifications.empty());
        }
    }

    SECTION("object change information") {
        auto realm = Realm::get_shared_realm(config);
        realm->update_schema({
            {"origin", {
                {"pk", PropertyType::Int, Property::IsPrimary{true}},
                {"link", PropertyType::Object|PropertyType::Nullable, "target"},
                {"array", PropertyType::Array|PropertyType::Object, "target"},
                {"int array", PropertyType::Array|PropertyType::Int},
            }},
            {"origin 2", {
                {"pk", PropertyType::Int, Property::IsPrimary{true}},
                {"link", PropertyType::Object|PropertyType::Nullable, "target"},
                {"array", PropertyType::Array|PropertyType::Object, "target"}
            }},
            {"target", {
                {"pk", PropertyType::Int, Property::IsPrimary{true}},
                {"value 1", PropertyType::Int},
                {"value 2", PropertyType::Int},
            }},
        });

        auto origin = realm->read_group().get_table("class_origin");
        auto target = realm->read_group().get_table("class_target");
        auto origin_cols = origin->get_column_keys();
        auto target_cols = target->get_column_keys();

        realm->begin_transaction();

        std::vector<ObjKey> target_keys;
        target->create_objects(10, target_keys);
        for (int i = 0; i < 10; ++i)
            target->get_object(target_keys[i]).set_all(i, i, i);

        std::vector<ObjKey> origin_keys;
        origin->create_objects(3, origin_keys);
        origin->get_object(origin_keys[0]).set_all(5, target_keys[5]);
        origin->get_object(origin_keys[1]).set_all(5, target_keys[6]);

        auto lv = origin->get_object(origin_keys[0]).get_linklist(origin_cols[2]);
        for (auto key : target_keys)
            lv.add(key);
        auto lv2 = origin->get_object(origin_keys[1]).get_linklist(origin_cols[2]);
        lv2.add(target_keys[0]);

        auto tr = origin->get_object(origin_keys[0]).get_list<int64_t>(origin_cols[3]);
        for (int i = 0; i < 10; ++i)
            tr.add(i);
        auto tr2 = origin->get_object(origin_keys[1]).get_list<int64_t>(origin_cols[3]);
        for (int i = 0; i < 10; ++i)
            tr2.add(0);

        realm->read_group().get_table("class_origin 2")->create_object();

        realm->commit_transaction();

        auto observe = [&](std::initializer_list<Obj> rows, auto&& fn) {
            auto realm2 = Realm::get_shared_realm(config);
            auto& group = realm2->read_group();
            static_cast<void>(group); // silence unused warning
            KVOContext observer(rows);
            observer.realm = realm2;
            realm2->m_binding_context.reset(&observer);

            realm->begin_transaction();
            lv.size(); lv2.size(); tr.size(); tr2.size();
            fn();
            realm->commit_transaction();
            lv.size(); lv2.size(); tr.size(); tr2.size();

            realm2->refresh();
            realm2->m_binding_context.release();

            return observer;
        };

        auto observe_rollback = [&](std::initializer_list<Obj> rows, auto&& fn) {
            KVOContext observer(rows);
            observer.realm = realm;
            realm->m_binding_context.reset(&observer);

            realm->begin_transaction();
            lv.size(); lv2.size(); tr.size(); tr2.size();
            fn();
            realm->cancel_transaction();
            lv.size(); lv2.size(); tr.size(); tr2.size();

            realm->m_binding_context.release();
            return observer;
        };

        SECTION("setting a property marks that property as changed") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
                o.set(target_cols[0], 1);
            });
            REQUIRE(changes.modified(0, target_cols[0]));
            REQUIRE_FALSE(changes.modified(0, target_cols[1]));
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));
        }

        SECTION("self-assignment marks as changed") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
                o.set(target_cols[0], o.get<int64_t>(target_cols[0]));
            });
            REQUIRE(changes.modified(0, target_cols[0]));
            REQUIRE_FALSE(changes.modified(0, target_cols[1]));
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));
        }

        SECTION("SetDefault does not mark as changed") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
                o.set(target_cols[0], 5, true);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[0]));
            REQUIRE_FALSE(changes.modified(0, target_cols[1]));
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));
        }

        SECTION("multiple properties on a single object are handled properly") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
                o.set(target_cols[1], 1);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[0]));
            REQUIRE(changes.modified(0, target_cols[1]));
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));

            changes = observe({o}, [&] {
                o.set(target_cols[2], 1);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[0]));
            REQUIRE_FALSE(changes.modified(0, target_cols[1]));
            REQUIRE(changes.modified(0, target_cols[2]));

            changes = observe({o}, [&] {
                o.set(target_cols[0], 1);
                o.set(target_cols[2], 1);
            });
            REQUIRE(changes.modified(0, target_cols[0]));
            REQUIRE_FALSE(changes.modified(0, target_cols[1]));
            REQUIRE(changes.modified(0, target_cols[2]));

            changes = observe({o}, [&] {
                o.set(target_cols[0], 1);
                o.set(target_cols[1], 1);
                o.set(target_cols[2], 1);
            });
            REQUIRE(changes.modified(0, target_cols[0]));
            REQUIRE(changes.modified(0, target_cols[1]));
            REQUIRE(changes.modified(0, target_cols[2]));
        }

        SECTION("setting other objects does not mark as changed") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
              target->get_object(target_keys[1]).set(target_cols[0], 5);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[0]));
            REQUIRE_FALSE(changes.modified(0, target_cols[1]));
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));
        }

        SECTION("deleting an observed object adds it to invalidated") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
                o.remove();
            });
            REQUIRE(changes.invalidated(0));
        }

        SECTION("deleting an unobserved object does nothing") {
            auto o = target->get_object(target_keys[0]);
            auto changes = observe({o}, [&] {
                target->get_object(target_keys[1]).remove();
            });
            REQUIRE_FALSE(changes.invalidated(0));
        }

        SECTION("deleting the target of a link marks the link as modified") {
            auto o = origin->get_object(origin_keys[0]);
            auto changes = observe({o}, [&] {
                o.get_linked_object(origin_cols[1]).remove();
            });
            REQUIRE(changes.modified(0, origin_cols[1]));
        }

        SECTION("clearing the target table of a link marks the link as modified") {
            auto o = origin->get_object(origin_keys[0]);
            auto changes = observe({o}, [&] {
                target->clear();
            });
            REQUIRE(changes.modified(0, origin_cols[1]));
        }

        SECTION("clearing a table invalidates all observers for that table") {
            auto r1 = target->get_object(target_keys[0]);
            auto r2 = target->get_object(target_keys[5]);
            auto r3 = origin->get_object(origin_keys[0]);
            auto changes = observe({r1, r2, r3}, [&] {
                target->clear();
            });
            REQUIRE(changes.invalidated(0));
            REQUIRE(changes.invalidated(1));
            REQUIRE_FALSE(changes.invalidated(2));
        }

        using Kind = BindingContext::ColumnInfo::Kind;
        auto o = origin->get_object(origin_keys[0]);
        const auto lv_col = origin_cols[2];
        SECTION("array: add()") {
            auto changes = observe({o}, [&] {
                lv.add(target_keys[0]);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {10}}));
        }

        SECTION("array: insert()") {
            auto changes = observe({o}, [&] {
                lv.insert(4, target_keys[0]);
                lv.insert(2, target_keys[0]);
                lv.insert(8, target_keys[0]);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {2, 5, 8}}));
        }

        SECTION("array: remove()") {
            auto changes = observe({o}, [&] {
                lv.remove(0);
                lv.remove(2);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Remove, {0, 3}}));
        }

        SECTION("array: set()") {
            auto changes = observe({o}, [&] {
                lv.set(0, target_keys[3]);
                lv.set(2, target_keys[3]);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {0, 2}}));
        }

        SECTION("array: move()") {
            SECTION("swap forward") {
                auto changes = observe({o}, [&] {
                    lv.move(3, 4);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {3, 4}}));
            }

            SECTION("swap backwards") {
                auto changes = observe({o}, [&] {
                    lv.move(4, 3);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {3, 4}}));
            }

            SECTION("move fowards") {
                auto changes = observe({o}, [&] {
                    lv.move(3, 5);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {3, 4, 5}}));
            }

            SECTION("move backwards") {
                auto changes = observe({o}, [&] {
                    lv.move(5, 3);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {3, 4, 5}}));
            }

            SECTION("multiple moves collapsing to nothing") {
                auto changes = observe({o}, [&] {
                    lv.move(3, 4);
                    lv.move(4, 5);
                    lv.move(5, 3);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::None, {}}));
            }

            SECTION("multiple moves") {
                auto changes = observe({o}, [&] {
                    lv.move(3, 6);
                    lv.move(6, 4);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {3, 4}}));

                changes = observe({o}, [&] {
                    lv.move(3, 6);
                    lv.move(6, 0);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {0, 1, 2, 3}}));

                changes = observe({o}, [&] {
                    lv.move(9, 0);
                    lv.move(1, 7);
                });
                REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {0, 7, 8, 9}}));
            }
        }

        SECTION("array: swap()") {
            auto changes = observe({o}, [&] {
                lv.swap(5, 3);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Set, {3, 5}}));
        }

        SECTION("array: clear()") {
            auto changes = observe({o}, [&] {
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: clear() after add()") {
            auto changes = observe({o}, [&] {
                lv.add(target_keys[0]);
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: clear() after set()") {
            auto changes = observe({o}, [&] {
                lv.set(5, target_keys[3]);
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: clear() after remove()") {
            auto changes = observe({o}, [&] {
                lv.remove(2);
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: rollback clear()") {
            auto changes = observe_rollback({o}, [&] {
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: rollback clear() after add()") {
            auto changes = observe_rollback({o}, [&] {
                lv.add(target_keys[0]);
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: rollback clear() after set()") {
            auto changes = observe_rollback({o}, [&] {
                lv.set(5, target_keys[3]);
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: rollback clear() after remove()") {
            auto changes = observe_rollback({o}, [&] {
                lv.remove(2);
                lv.clear();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("array: rollback add after clear()") {
            auto changes = observe_rollback({o}, [&] {
                lv.clear();
                lv.add(target_keys[0]);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::SetAll, {}}));
        }

        SECTION("array: multiple change kinds") {
            auto changes = observe({o}, [&] {
                lv.add(target_keys[0]);
                lv.remove(0);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::SetAll, {}}));
        }

        SECTION("array: modify newly inserted row") {
            auto changes = observe({o}, [&] {
                lv.add(target_keys[0]);
                lv.set(lv.size() - 1, target_keys[1]);
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::Insert, {10}}));
        }

        SECTION("array: modifying different array does not produce changes") {
            auto changes = observe({o}, [&] {
                lv2.add(target_keys[0]);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));
        }

        SECTION("array: modifying different table does not produce changes") {
            auto changes = observe({o}, [&] {
                realm->read_group().get_table("class_origin 2")->begin()->get_linklist("array").add(target_keys[0]);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[2]));
        }

        SECTION("array: deleting the containing row after making changes discards the changes") {
            auto changes = observe({o}, [&] {
                lv.insert(4, target_keys[0]);
                lv.insert(2, target_keys[0]);
                lv.insert(8, target_keys[0]);
                o.remove();
            });
            REQUIRE(changes.array_change(0, lv_col) == (ArrayChange{Kind::None, {}}));
        }

        // ----------------------------------------------------------------------

        const auto tr_col = origin_cols[3];
        SECTION("int array: add()") {
            auto changes = observe({o}, [&] {
                tr.add(0);
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Insert, {10}}));
        }

        SECTION("int array: insert()") {
            auto changes = observe({o}, [&] {
                tr.insert(4, 0);
                tr.insert(2, 0);
                tr.insert(8, 0);
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Insert, {2, 5, 8}}));
        }

        SECTION("int array: remove()") {
            auto changes = observe({o}, [&] {
                tr.remove(0);
                tr.remove(2);
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Remove, {0, 3}}));
        }

        SECTION("int array: set()") {
            auto changes = observe({o}, [&] {
                tr.set(0, 3);
                tr.set(2, 3);
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Set, {0, 2}}));
        }

        SECTION("int array: move()") {
            auto changes = observe({o}, [&] {
                tr.move(8, 2);
                tr.move(4, 6);

                //      0, 1, 2, 3, 4, 5, 6, 7, 8, 9
                // Now: 0, 1, 8, 2, 4, 5, 3, 6, 7, 9
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Set, {2, 3, 6, 7, 8}}));
        }

        SECTION("int array: emulated move()") {
            auto changes = observe({o}, [&] {
                // list.move(8, 2);
                tr.insert(2, 0);
                tr.swap(9, 2);
                tr.remove(9);

                // list.move(4, 6);
                tr.insert(7, 0);
                tr.swap(4, 7);
                tr.remove(4);

                //      0, 1, 2, 3, 4, 5, 6, 7, 8, 9
                // Now: 0, 1, 8, 2, 4, 5, 3, 6, 7, 9
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Set, {2, 3, 6, 7, 8}}));
        }

        SECTION("int array: swap()") {
            SECTION("adjacent") {
                auto changes = observe({o}, [&] {
                    tr.swap(5, 4);
                });
                REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Set, {4, 5}}));
            }
            SECTION("non-adjacent") {
                auto changes = observe({o}, [&] {
                    tr.swap(5, 3);
                });
                REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Set, {3, 5}}));
            }
        }

        SECTION("int array: clear()") {
            auto changes = observe({o}, [&] {
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: clear() after add()") {
            auto changes = observe({o}, [&] {
                tr.add(0);
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: clear() after set()") {
            auto changes = observe({o}, [&] {
                tr.set(5, 3);
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: clear() after remove()") {
            auto changes = observe({o}, [&] {
                tr.remove(2);
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Remove, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: multiple change kinds") {
            auto changes = observe({o}, [&] {
                tr.add(0);
                tr.remove(0);
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::SetAll, {}}));
        }

        SECTION("int array: modifying different array does not produce changes") {
            auto changes = observe({o}, [&] {
                tr2.add(0);
            });
            REQUIRE_FALSE(changes.modified(0, target_cols[3]));
        }

        SECTION("int array: deleting the containing row after making changes discards the changes") {
            auto changes = observe({o}, [&] {
                tr.insert(4, 0);
                tr.insert(2, 0);
                tr.insert(8, 0);
                o.remove();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::None, {}}));
        }

        SECTION("int array: rollback clear()") {
            auto changes = observe_rollback({o}, [&] {
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: rollback clear() after add()") {
            auto changes = observe_rollback({o}, [&] {
                tr.add(0);
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: rollback clear() after set()") {
            auto changes = observe_rollback({o}, [&] {
                tr.set(5, 3);
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: rollback clear() after remove()") {
            auto changes = observe_rollback({o}, [&] {
                tr.remove(2);
                tr.clear();
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::Insert, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}}));
        }

        SECTION("int array: rollback add() after clear()") {
            auto changes = observe_rollback({o}, [&] {
                tr.clear();
                tr.add(0);
            });
            REQUIRE(changes.array_change(0, tr_col) == (ArrayChange{Kind::SetAll, {}}));
        }
    }
}

TEST_CASE("DeepChangeChecker") {
    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"table", {
            {"int", PropertyType::Int},
            {"link1", PropertyType::Object|PropertyType::Nullable, "table"},
            {"link2", PropertyType::Object|PropertyType::Nullable, "table"},
            {"array", PropertyType::Array|PropertyType::Object, "table"}
        }},
    });
    auto table = r->read_group().get_table("class_table");

    std::vector<Obj> objects;
    r->begin_transaction();
    for (int i = 0; i < 10; ++i)
        objects.push_back(table->create_object().set_all(i));
    r->commit_transaction();

    auto track_changes = [&](auto&& f) {
        auto history = make_in_realm_history(config.path);
        auto db = DB::create(*history, config.options());
        auto rt = db->start_read();

        r->begin_transaction();
        f();
        r->commit_transaction();

        _impl::TransactionChangeInfo info{};
        for (auto key : rt->get_table_keys())
            info.tables[key.value];
        _impl::transaction::advance(*rt, info);
        return info;
    };

    std::vector<_impl::DeepChangeChecker::RelatedTable> tables;
    _impl::DeepChangeChecker::find_related_tables(tables, *table);

    auto cols = table->get_column_keys();
    SECTION("direct changes are tracked") {
        auto info = track_changes([&] {
            table->get_object(9).set(cols[0], 10);
        });

        _impl::DeepChangeChecker checker(info, *table, tables);
        REQUIRE_FALSE(checker(8));
        REQUIRE(checker(9));
    }

    SECTION("changes over links are tracked") {
        bool did_run_section = false;
        SECTION("first link set") {
            did_run_section = true;
            r->begin_transaction();
            objects[0].set(cols[1], objects[1].get_key());
            objects[1].set(cols[1], objects[2].get_key());
            objects[2].set(cols[1], objects[4].get_key());
            r->commit_transaction();
        }
        SECTION("second link set") {
            did_run_section = true;
            r->begin_transaction();
            objects[0].set(cols[2], objects[1].get_key());
            objects[1].set(cols[2], objects[2].get_key());
            objects[2].set(cols[2], objects[4].get_key());
            r->commit_transaction();
        }
        SECTION("both set") {
            did_run_section = true;
            r->begin_transaction();
            objects[0].set(cols[1], objects[1].get_key());
            objects[1].set(cols[1], objects[2].get_key());
            objects[2].set(cols[1], objects[4].get_key());

            objects[0].set(cols[2], objects[1].get_key());
            objects[1].set(cols[2], objects[2].get_key());
            objects[2].set(cols[2], objects[4].get_key());
            r->commit_transaction();
        }
        SECTION("circular link") {
            did_run_section = true;
            r->begin_transaction();
            objects[0].set(cols[1], objects[0].get_key());
            objects[1].set(cols[1], objects[1].get_key());
            objects[2].set(cols[1], objects[2].get_key());
            objects[3].set(cols[1], objects[3].get_key());
            objects[4].set(cols[1], objects[4].get_key());

            objects[0].set(cols[2], objects[1].get_key());
            objects[1].set(cols[2], objects[2].get_key());
            objects[2].set(cols[2], objects[4].get_key());
            r->commit_transaction();
        }

        catch2_ensure_section_run_workaround(did_run_section, "changes over links are tracked", [&]() {
            auto info = track_changes([&] {
                objects[4].set(cols[0], 10);
            });

            // link chain should cascade to all but #3 being marked as modified
            REQUIRE(_impl::DeepChangeChecker(info, *table, tables)(0));
            REQUIRE(_impl::DeepChangeChecker(info, *table, tables)(1));
            REQUIRE(_impl::DeepChangeChecker(info, *table, tables)(2));
            REQUIRE_FALSE(_impl::DeepChangeChecker(info, *table, tables)(3));

        });
    }

    SECTION("changes over linklists are tracked") {
        r->begin_transaction();
        for (int i = 0; i < 3; ++i) {
            objects[i].get_linklist(cols[3]).add(objects[i].get_key());
            objects[i].get_linklist(cols[3]).add(objects[i].get_key());
            objects[i].get_linklist(cols[3]).add(objects[i + 1 + (i == 2)].get_key());
        }
        r->commit_transaction();

        auto info = track_changes([&] {
            objects[4].set(cols[0], 10);
        });

        REQUIRE(_impl::DeepChangeChecker(info, *table, tables)(0));
        REQUIRE_FALSE(_impl::DeepChangeChecker(info, *table, tables)(3));
    }

    SECTION("cycles over links do not loop forever") {
        r->begin_transaction();
        objects[0].set(cols[1], objects[0].get_key());
        r->commit_transaction();

        auto info = track_changes([&] {
            objects[9].set(cols[0], 10);
        });
        REQUIRE_FALSE(_impl::DeepChangeChecker(info, *table, tables)(0));
    }

    SECTION("cycles over linklists do not loop forever") {
        r->begin_transaction();
        objects[0].get_linklist(cols[3]).add(objects[0].get_key());
        r->commit_transaction();

        auto info = track_changes([&] {
            objects[9].set(cols[0], 10);
        });
        REQUIRE_FALSE(_impl::DeepChangeChecker(info, *table, tables)(0));
    }

    SECTION("link chains are tracked up to 4 levels deep") {
        r->begin_transaction();
        for (int i = 0; i < 10; ++i)
            objects.push_back(table->create_object());
        for (int i = 0; i < 19; ++i)
            objects[i].set(cols[1], objects[i + 1].get_key());
        r->commit_transaction();

        auto info = track_changes([&] {
            objects[19].set(cols[0], -1);
        });

        _impl::DeepChangeChecker checker(info, *table, tables);
        CHECK(checker(19));
        CHECK(checker(18));
        CHECK(checker(16));
        CHECK_FALSE(checker(15));

        // Check in other orders to make sure that the caching doesn't effect
        // the results
        _impl::DeepChangeChecker checker2(info, *table, tables);
        CHECK_FALSE(checker2(15));
        CHECK(checker2(16));
        CHECK(checker2(18));
        CHECK(checker2(19));

        _impl::DeepChangeChecker checker3(info, *table, tables);
        CHECK(checker3(16));
        CHECK_FALSE(checker3(15));
        CHECK(checker3(18));
        CHECK(checker3(19));
    }

    SECTION("changes made in the 3rd elements in the link list") {
        r->begin_transaction();
        objects[0].get_linklist(cols[3]).add(objects[1].get_key());
        objects[0].get_linklist(cols[3]).add(objects[2].get_key());
        objects[0].get_linklist(cols[3]).add(objects[3].get_key());
        objects[1].set(cols[1], objects[0].get_key());
        objects[2].set(cols[1], objects[0].get_key());
        objects[3].set(cols[1], objects[0].get_key());
        r->commit_transaction();

        auto info = track_changes([&] {
            objects[3].set(cols[0], 42);
        });
        _impl::DeepChangeChecker checker(info, *table, tables);
        REQUIRE(checker(1));
        REQUIRE(checker(2));
        REQUIRE(checker(3));
    }

    SECTION("changes made to lists mark the containing row as modified") {
        auto info = track_changes([&] {
            objects[0].get_linklist(cols[3]).add(objects[1].get_key());
        });
        _impl::DeepChangeChecker checker(info, *table, tables);
        REQUIRE(checker(0));
    }
}
