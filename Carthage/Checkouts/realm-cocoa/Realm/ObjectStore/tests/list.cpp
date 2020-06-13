////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

#include "util/test_file.hpp"
#include "util/index_helpers.hpp"

#include "binding_context.hpp"
#include "list.hpp"
#include "object.hpp"
#include "object_schema.hpp"
#include "property.hpp"
#include "results.hpp"
#include "schema.hpp"

#include "impl/realm_coordinator.hpp"
#include "impl/object_accessor_impl.hpp"

#include <realm/version.hpp>
#include <realm/db.hpp>

#include <cstdint>

using namespace realm;

TEST_CASE("list") {
    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"origin", {
            {"pk", PropertyType::Int, Property::IsPrimary{true}},
            {"array", PropertyType::Array|PropertyType::Object, "target"}
        }},
        {"target", {
            {"value", PropertyType::Int}
        }},
        {"other_origin", {
            {"array", PropertyType::Array|PropertyType::Object, "other_target"}
        }},
        {"other_target", {
            {"value", PropertyType::Int}
        }},
    });

    auto& coordinator = *_impl::RealmCoordinator::get_coordinator(config.path);

    auto origin = r->read_group().get_table("class_origin");
    auto target = r->read_group().get_table("class_target");
    auto other_origin = r->read_group().get_table("class_other_origin");
    auto other_target = r->read_group().get_table("class_other_target");
    ColKey col_link = origin->get_column_key("array");
    ColKey col_value = target->get_column_key("value");
    ColKey other_col_link = other_origin->get_column_key("array");
    ColKey other_col_value = other_target->get_column_key("value");

    r->begin_transaction();

    std::vector<ObjKey> target_keys;
    target->create_objects(10, target_keys);
    for (int i = 0; i < 10; ++i)
        target->get_object(target_keys[i]).set_all(i);

    Obj obj = origin->create_object();
    auto lv = obj.get_linklist_ptr(col_link);
    for (int i = 0; i < 10; ++i)
        lv->add(target_keys[i]);
    auto lv2 = origin->create_object().get_linklist_ptr(col_link);
    for (int i = 0; i < 10; ++i)
        lv2->add(target_keys[i]);

    ObjKeys other_target_keys({3, 5, 7, 9, 11, 13, 15, 17, 19, 21});
    other_target->create_objects(other_target_keys);
    for (int i = 0; i < 10; ++i)
        other_target->get_object(other_target_keys[i]).set_all(i);

    Obj other_obj = other_origin->create_object();
    auto other_lv = other_obj.get_linklist_ptr(other_col_link);
    for (int i = 0; i < 10; ++i)
        other_lv->add(other_target_keys[i]);

    r->commit_transaction();

    auto r2 = coordinator.get_realm();
    auto r2_lv = r2->read_group().get_table("class_origin")->get_object(0).get_linklist_ptr(col_link);

    SECTION("add_notification_block()") {
        CollectionChangeSet change;
        List lst(r, obj, col_link);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();

            advance_and_notify(*r);
        };

        auto require_change = [&] {
            auto token = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            advance_and_notify(*r);
            return token;
        };

        auto require_no_change = [&] {
            bool first = true;
            auto token = lst.add_notification_callback([&, first](CollectionChangeSet, std::exception_ptr) mutable {
                REQUIRE(first);
                first = false;
            });
            advance_and_notify(*r);
            return token;
        };

        SECTION("modifying the list sends a change notifications") {
            auto token = require_change();
            write([&] { if (lv2->size() > 5) lst.remove(5); });
            REQUIRE_INDICES(change.deletions, 5);
        }

        SECTION("modifying a different list doesn't send a change notification") {
            auto token = require_no_change();
            write([&] { if (lv2->size() > 5) lv2->remove(5); });
        }

        SECTION("deleting the list sends a change notification") {
            auto token = require_change();
            write([&] { obj.remove(); });
            REQUIRE_INDICES(change.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);

            // Should not resend delete all notification after another commit
            change = {};
            write([&] { target->create_object(); });
            REQUIRE(change.empty());
        }

        SECTION("deleting list before first run of notifier reports deletions") {
            auto token = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            advance_and_notify(*r);
            write([&] { origin->begin()->remove(); });
            REQUIRE_INDICES(change.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
        }

        SECTION("modifying one of the target rows sends a change notification") {
            auto token = require_change();
            write([&] { lst.get(5).set(col_value, 6); });
            REQUIRE_INDICES(change.modifications, 5);
        }

        SECTION("deleting a target row sends a change notification") {
            auto token = require_change();
            write([&] { target->remove_object(target_keys[5]); });
            REQUIRE_INDICES(change.deletions, 5);
        }

        SECTION("adding a row and then modifying the target row does not mark the row as modified") {
            auto token = require_change();
            write([&] {
                Obj obj = target->get_object(target_keys[5]);
                lst.add(obj);
                obj.set(col_value, 10);
            });
            REQUIRE_INDICES(change.insertions, 10);
            REQUIRE_INDICES(change.modifications, 5);
        }

        SECTION("modifying and then moving a row reports move/insert but not modification") {
            auto token = require_change();
            write([&] {
                target->get_object(target_keys[5]).set(col_value, 10);
                lst.move(5, 8);
            });
            REQUIRE_INDICES(change.insertions, 8);
            REQUIRE_INDICES(change.deletions, 5);
            REQUIRE_MOVES(change, {5, 8});
            REQUIRE(change.modifications.empty());
        }

        SECTION("modifying a row which appears multiple times in a list marks them all as modified") {
            r->begin_transaction();
            lst.add(target_keys[5]);
            r->commit_transaction();

            auto token = require_change();
            write([&] { target->get_object(target_keys[5]).set(col_value, 10); });
            REQUIRE_INDICES(change.modifications, 5, 10);
        }

        SECTION("deleting a row which appears multiple times in a list marks them all as modified") {
            r->begin_transaction();
            lst.add(target_keys[5]);
            r->commit_transaction();

            auto token = require_change();
            write([&] { target->remove_object(target_keys[5]); });
            REQUIRE_INDICES(change.deletions, 5, 10);
        }

        SECTION("clearing the target table sends a change notification") {
            auto token = require_change();
            write([&] { target->clear(); });
            REQUIRE_INDICES(change.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
        }

        SECTION("moving a target row does not send a change notification") {
            // Remove a row from the LV so that we have one to delete that's not in the list
            r->begin_transaction();
            if (lv->size() > 2)
                lv->remove(2);
            r->commit_transaction();

            auto token = require_no_change();
            write([&] { target->remove_object(target_keys[2]); });
        }

        SECTION("multiple LinkViews for the same LinkList can get notifications") {
            r->begin_transaction();
            target->clear();
            std::vector<ObjKey> keys;
            target->create_objects(5, keys);
            r->commit_transaction();

            auto get_list = [&] {
                auto r = Realm::get_shared_realm(config);
                auto obj = r->read_group().get_table("class_origin")->get_object(0);
                return List(r, obj, col_link);
            };
            auto change_list = [&] {
                r->begin_transaction();
                if (lv->size()) {
                    target->get_object(lv->size() - 1).set(col_value, int64_t(lv->size()));
                }
                lv->add(keys[lv->size()]);
                r->commit_transaction();
            };

            List lists[3];
            NotificationToken tokens[3];
            CollectionChangeSet changes[3];

            for (int i = 0; i < 3; ++i) {
                lists[i] = get_list();
                tokens[i] = lists[i].add_notification_callback([i, &changes](CollectionChangeSet c, std::exception_ptr) {
                    changes[i] = std::move(c);
                });
                change_list();
            }

            // Each of the Lists now has a different source version and state at
            // that version, so they should all see different changes despite
            // being for the same LinkList
            for (auto& list : lists)
                advance_and_notify(*list.get_realm());

            REQUIRE_INDICES(changes[0].insertions, 0, 1, 2);
            REQUIRE(changes[0].modifications.empty());

            REQUIRE_INDICES(changes[1].insertions, 1, 2);
            REQUIRE_INDICES(changes[1].modifications, 0);

            REQUIRE_INDICES(changes[2].insertions, 2);
            REQUIRE_INDICES(changes[2].modifications, 1);

            // After making another change, they should all get the same notification
            change_list();
            for (auto& list : lists)
                advance_and_notify(*list.get_realm());

            for (int i = 0; i < 3; ++i) {
                REQUIRE_INDICES(changes[i].insertions, 3);
                REQUIRE_INDICES(changes[i].modifications, 2);
            }
        }

        SECTION("multiple callbacks for the same Lists can be skipped individually") {
            auto token = require_no_change();
            auto token2 = require_change();

            r->begin_transaction();
            lv->add(target_keys[0]);
            token.suppress_next();
            r->commit_transaction();

            advance_and_notify(*r);
            REQUIRE_INDICES(change.insertions, 10);
        }

        SECTION("multiple Lists for the same LinkView can be skipped individually") {
            auto token = require_no_change();

            List list2(r, obj, col_link);
            auto token2 = list2.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            advance_and_notify(*r);

            r->begin_transaction();
            lv->add(target_keys[0]);
            token.suppress_next();
            r->commit_transaction();

            advance_and_notify(*r);
            REQUIRE_INDICES(change.insertions, 10);
        }

        SECTION("skipping only effects the current transaction even if no notification would occur anyway") {
            auto token = require_change();

            // would not produce a notification even if it wasn't skipped because no changes were made
            r->begin_transaction();
            token.suppress_next();
            r->commit_transaction();
            advance_and_notify(*r);
            REQUIRE(change.empty());

            // should now produce a notification
            r->begin_transaction();
            lv->add(target_keys[0]);
            r->commit_transaction();
            advance_and_notify(*r);
            REQUIRE_INDICES(change.insertions, 10);
        }

        SECTION("modifying a different table does not send a change notification") {
            auto token = require_no_change();
            write([&] { other_lv->add(other_target_keys[0]); });
        }

        SECTION("changes are reported correctly for multiple tables") {
            List list2(r, *other_lv);
            CollectionChangeSet other_changes;
            auto token1 = list2.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                other_changes = std::move(c);
            });
            auto token2 = require_change();

            write([&] {
                lv->add(target_keys[1]);

                other_origin->create_object();
                if (other_lv->size() > 0)
                    other_lv->insert(1, other_target_keys[0]);

                lv->add(target_keys[2]);
            });
            REQUIRE_INDICES(change.insertions, 10, 11);
            REQUIRE_INDICES(other_changes.insertions, 1);

            write([&] {
                lv->add(target_keys[3]);
                other_obj.remove();
                lv->add(target_keys[4]);
            });
            REQUIRE_INDICES(change.insertions, 12, 13);
            REQUIRE_INDICES(other_changes.deletions, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

            write([&] {
                lv->add(target_keys[5]);
                other_origin->clear();
                lv->add(target_keys[6]);
            });
            REQUIRE_INDICES(change.insertions, 14, 15);
        }

        SECTION("tables-of-interest are tracked properly for multiple source versions") {
            // Add notifiers for different tables at different versions to verify
            // that the tables of interest are updated correctly as we process
            // new notifiers
            CollectionChangeSet changes1, changes2;
            auto token1 = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                changes1 = std::move(c);
            });

            r2->begin_transaction();
            r2->read_group().get_table("class_target")->get_object(target_keys[0]).set(col_value, 10);
            r2->read_group().get_table("class_other_target")->get_object(other_target_keys[1]).set(other_col_value, 10);
            r2->commit_transaction();

            List list2(r2, r2->read_group().get_table("class_other_origin")->get_object(0), other_col_link);
            auto token2 = list2.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                changes2 = std::move(c);
            });

            auto r3 = coordinator.get_realm();
            r3->begin_transaction();
            r3->read_group().get_table("class_target")->get_object(target_keys[2]).set(col_value, 10);
            r3->read_group().get_table("class_other_target")->get_object(other_target_keys[3]).set(other_col_value, 10);
            r3->commit_transaction();

            advance_and_notify(*r);
            advance_and_notify(*r2);

            REQUIRE_INDICES(changes1.modifications, 0, 2);
            REQUIRE_INDICES(changes2.modifications, 3);
        }

        SECTION("modifications are reported for rows that are moved and then moved back in a second transaction") {
            auto token = require_change();

            r2->begin_transaction();
            r2_lv->get_object(5).set(col_value, 10);
            r2_lv->get_object(1).set(col_value, 10);
            r2_lv->move(5, 8);
            r2_lv->move(1, 2);
            r2->commit_transaction();

            coordinator.on_change();

            r2->begin_transaction();
            if (r2_lv->size() > 8)
                r2_lv->move(8, 5);
            r2->commit_transaction();
            advance_and_notify(*r);

            REQUIRE_INDICES(change.deletions, 1);
            REQUIRE_INDICES(change.insertions, 2);
            REQUIRE_INDICES(change.modifications, 5);
            REQUIRE_MOVES(change, {1, 2});
        }

        SECTION("changes are sent in initial notification") {
            auto token = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            r2->begin_transaction();
            r2_lv->remove(5);
            r2->commit_transaction();
            advance_and_notify(*r);
            REQUIRE_INDICES(change.deletions, 5);
        }

        SECTION("changes are sent in initial notification after removing and then re-adding callback") {
            auto token = lst.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                REQUIRE(false);
            });
            token = {};

            auto write = [&] {
                r2->begin_transaction();
                r2_lv->remove(5);
                r2->commit_transaction();
            };

            SECTION("add new callback before transaction") {
                token = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                    change = c;
                });

                write();

                advance_and_notify(*r);
                REQUIRE_INDICES(change.deletions, 5);
            }

            SECTION("add new callback after transaction") {
                write();

                token = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                    change = c;
                });

                advance_and_notify(*r);
                REQUIRE_INDICES(change.deletions, 5);
            }

            SECTION("add new callback after transaction and after changeset was calculated") {
                write();
                coordinator.on_change();

                token = lst.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                    change = c;
                });

                advance_and_notify(*r);
                REQUIRE_INDICES(change.deletions, 5);
            }
        }
    }

    SECTION("sorted add_notification_block()") {
        List lst(r, *lv);
        Results results = lst.sort({{{col_value}}, {false}});

        int notification_calls = 0;
        CollectionChangeSet change;
        auto token = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            change = c;
            ++notification_calls;
        });

        advance_and_notify(*r);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();

            advance_and_notify(*r);
        };
        SECTION("add duplicates") {
            write([&] {
                lst.add(target_keys[5]);
                lst.add(target_keys[5]);
                lst.add(target_keys[5]);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 5, 6, 7);
        }

        SECTION("change order by modifying target") {
            write([&] {
                lst.get(5).set(col_value, 15);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 4);
            REQUIRE_INDICES(change.insertions, 0);
        }

        SECTION("swap") {
            write([&] {
                lst.swap(1, 2);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("move") {
            write([&] {
                lst.move(5, 3);
            });
            REQUIRE(notification_calls == 1);
        }
    }

    SECTION("filtered add_notification_block()") {
        List lst(r, *lv);
        Results results = lst.filter(target->where().less(col_value, 9));

        int notification_calls = 0;
        CollectionChangeSet change;
        auto token = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            change = c;
            ++notification_calls;
        });

        advance_and_notify(*r);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();

            advance_and_notify(*r);
        };
        SECTION("add duplicates") {
            write([&] {
                lst.add(target_keys[5]);
                lst.add(target_keys[5]);
                lst.add(target_keys[5]);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 9, 10, 11);
        }

        SECTION("swap") {
            write([&] {
                lst.swap(1, 2);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 2);
            REQUIRE_INDICES(change.insertions, 1);

            write([&] {
                lst.swap(5, 8);
            });
            REQUIRE(notification_calls == 3);
            REQUIRE_INDICES(change.deletions, 5, 8);
            REQUIRE_INDICES(change.insertions, 5, 8);
        }

        SECTION("move") {
            write([&] {
                lst.move(5, 3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 5);
            REQUIRE_INDICES(change.insertions, 3);
        }

        SECTION("move non-matching entry") {
            write([&] {
                lst.move(9, 3);
            });
            REQUIRE(notification_calls == 1);
        }
    }

    SECTION("sort()") {
        auto objectschema = &*r->schema().find("target");
        List list(r, *lv);
        auto results = list.sort({{{col_value}}, {false}});

        REQUIRE(&results.get_object_schema() == objectschema);
        REQUIRE(results.get_mode() == Results::Mode::LinkList);
        REQUIRE(results.size() == 10);

        // Aggregates don't inherently have to convert to TableView, but do
        // because aggregates aren't implemented for LinkView
        REQUIRE(results.sum(col_value) == 45);
        REQUIRE(results.get_mode() == Results::Mode::TableView);

        // Reset to LinkView mode to test implicit conversion to TableView on get()
        results = list.sort({{{col_value}}, {false}});
        for (size_t i = 0; i < 10; ++i)
            REQUIRE(results.get(i).get_key() == target_keys[9 - i]);
        REQUIRE_THROWS_WITH(results.get(10), "Requested index 10 greater than max 9");
        REQUIRE(results.get_mode() == Results::Mode::TableView);

        // Zero sort columns should leave it in LinkView mode
        results = list.sort(SortDescriptor());
        for (size_t i = 0; i < 10; ++i)
            REQUIRE(results.get(i).get_key() == target_keys[i]);
        REQUIRE_THROWS_WITH(results.get(10), "Requested index 10 greater than max 9");
        REQUIRE(results.get_mode() == Results::Mode::LinkList);
    }

    SECTION("filter()") {
        auto objectschema = &*r->schema().find("target");
        List list(r, *lv);
        auto results = list.filter(target->where().greater(col_value, 5));

        REQUIRE(&results.get_object_schema() == objectschema);
        REQUIRE(results.get_mode() == Results::Mode::Query);
        REQUIRE(results.size() == 4);

        for (size_t i = 0; i < 4; ++i) {
            REQUIRE(results.get(i).get_key().value == i + 6);
        }
    }

    SECTION("snapshot()") {
        auto objectschema = &*r->schema().find("target");
        List list(r, *lv);

        auto snapshot = list.snapshot();
        REQUIRE(&snapshot.get_object_schema() == objectschema);
        REQUIRE(snapshot.get_mode() == Results::Mode::TableView);
        REQUIRE(snapshot.size() == 10);

        r->begin_transaction();
        for (size_t i = 0; i < 5; ++i) {
            list.remove(0);
        }
        REQUIRE(snapshot.size() == 10);
        for (size_t i = 0; i < snapshot.size(); ++i) {
            REQUIRE(snapshot.get(i).is_valid());
        }
        for (size_t i = 0; i < 5; ++i) {
            target->remove_object(target_keys[i]);
        }
        REQUIRE(snapshot.size() == 10);
        for (size_t i = 0; i < 5; ++i) {
            REQUIRE(!snapshot.get(i).is_valid());
        }
        for (size_t i = 5; i < 10; ++i) {
            REQUIRE(snapshot.get(i).is_valid());
        }
        list.add(target_keys[5]);
        REQUIRE(snapshot.size() == 10);
    }

    SECTION("get_object_schema()") {
        List list(r, *lv);
        auto objectschema = &*r->schema().find("target");
        REQUIRE(&list.get_object_schema() == objectschema);
    }

    SECTION("delete_at()") {
        List list(r, *lv);
        r->begin_transaction();
        auto initial_view_size = lv->size();
        auto initial_target_size = target->size();
        list.delete_at(1);
        REQUIRE(lv->size() == initial_view_size - 1);
        REQUIRE(target->size() == initial_target_size - 1);
        r->cancel_transaction();
    }

    SECTION("delete_all()") {
        List list(r, *lv);
        r->begin_transaction();
        list.delete_all();
        REQUIRE(lv->size() == 0);
        REQUIRE(target->size() == 0);
        r->cancel_transaction();
    }

    SECTION("as_results().clear()") {
        List list(r, *lv);
        r->begin_transaction();
        list.as_results().clear();
        REQUIRE(lv->size() == 0);
        REQUIRE(target->size() == 0);
        r->cancel_transaction();
    }

    SECTION("snapshot().clear()") {
        List list(r, *lv);
        r->begin_transaction();
        auto snapshot = list.snapshot();
        snapshot.clear();
        REQUIRE(snapshot.size() == 10);
        REQUIRE(list.size() == 0);
        REQUIRE(lv->size() == 0);
        REQUIRE(target->size() == 0);
        r->cancel_transaction();
    }

    SECTION("add(RowExpr)") {
        List list(r, *lv);
        r->begin_transaction();
        SECTION("adds rows from the correct table") {
            list.add(target_keys[5]);
            REQUIRE(list.size() == 11);
            REQUIRE(list.get(10).get_key() == target_keys[5]);
        }

        SECTION("throws for rows from the wrong table") {
            REQUIRE_THROWS(list.add(obj));
        }
        r->cancel_transaction();
    }

    SECTION("insert(RowExpr)") {
        List list(r, *lv);
        r->begin_transaction();

        SECTION("insert rows from the correct table") {
            list.insert(0, target_keys[5]);
            REQUIRE(list.size() == 11);
            REQUIRE(list.get(0).get_key() == target_keys[5]);
        }

        SECTION("throws for rows from the wrong table") {
            REQUIRE_THROWS(list.insert(0, obj));
        }

        SECTION("throws for out of bounds insertions") {
            REQUIRE_THROWS(list.insert(11, target_keys[5]));
            REQUIRE_NOTHROW(list.insert(10, target_keys[5]));
        }
        r->cancel_transaction();
    }

    SECTION("set(RowExpr)") {
        List list(r, *lv);
        r->begin_transaction();

        SECTION("assigns for rows from the correct table") {
            list.set(0, target_keys[5]);
            REQUIRE(list.size() == 10);
            REQUIRE(list.get(0).get_key() == target_keys[5]);
        }

        SECTION("throws for rows from the wrong table") {
            REQUIRE_THROWS(list.set(0, obj));
        }

        SECTION("throws for out of bounds sets") {
            REQUIRE_THROWS(list.set(10, target_keys[5]));
        }
        r->cancel_transaction();
    }

    SECTION("find(RowExpr)") {
        List list(r, *lv);
        Obj obj1 = target->get_object(target_keys[1]);
        Obj obj5 = target->get_object(target_keys[5]);

        SECTION("returns index in list for values in the list") {
            REQUIRE(list.find(obj5) == 5);
        }

        SECTION("returns index in list and not index in table") {
            r->begin_transaction();
            list.remove(1);
            REQUIRE(list.find(obj5) == 4);
            REQUIRE(list.as_results().index_of(obj5) == 4);
            r->cancel_transaction();
        }

        SECTION("returns npos for values not in the list") {
            r->begin_transaction();
            list.remove(1);
            REQUIRE(list.find(obj1) == npos);
            REQUIRE(list.as_results().index_of(obj1) == npos);
            r->cancel_transaction();
        }

        SECTION("throws for row in wrong table") {
            REQUIRE_THROWS(list.find(obj));
            REQUIRE_THROWS(list.as_results().index_of(obj));
        }
    }

    SECTION("find(Query)") {
        List list(r, *lv);

        SECTION("returns index in list for values in the list") {
            REQUIRE(list.find(std::move(target->where().equal(col_value, 5))) == 5);
        }

        SECTION("returns index in list and not index in table") {
            r->begin_transaction();
            list.remove(1);
            REQUIRE(list.find(std::move(target->where().equal(col_value, 5))) == 4);
            r->cancel_transaction();
        }

        SECTION("returns npos for values not in the list") {
            REQUIRE(list.find(std::move(target->where().equal(col_value, 11))) == npos);
        }
    }

    SECTION("add(Context)") {
        List list(r, *lv);
        CppContext ctx(r, &list.get_object_schema());
        r->begin_transaction();

        SECTION("adds boxed RowExpr") {
            list.add(ctx, util::Any(target->get_object(target_keys[5])));
            REQUIRE(list.size() == 11);
            REQUIRE(list.get(10).get_key().value == 5);
        }

        SECTION("adds boxed realm::Object") {
            realm::Object obj(r, list.get_object_schema(), target->get_object(target_keys[5]));
            list.add(ctx, util::Any(obj));
            REQUIRE(list.size() == 11);
            REQUIRE(list.get(10).get_key() == target_keys[5]);
        }

        SECTION("creates new object for dictionary") {
            list.add(ctx, util::Any(AnyDict{{"value", INT64_C(20)}}));
            REQUIRE(list.size() == 11);
            REQUIRE(target->size() == 11);
            REQUIRE(list.get(10).get<Int>(col_value) == 20);
        }

        SECTION("throws for object in wrong table") {
            REQUIRE_THROWS(list.add(ctx, util::Any(origin->get_object(0))));
            realm::Object object(r, *r->schema().find("origin"), origin->get_object(0));
            REQUIRE_THROWS(list.add(ctx, util::Any(object)));
        }

        r->cancel_transaction();
    }

    SECTION("find(Context)") {
        List list(r, *lv);
        CppContext ctx(r, &list.get_object_schema());

        SECTION("returns index in list for boxed RowExpr") {
            REQUIRE(list.find(ctx, util::Any(target->get_object(target_keys[5]))) == 5);
        }

        SECTION("returns index in list for boxed Object") {
            realm::Object obj(r, *r->schema().find("origin"), target->get_object(target_keys[5]));
            REQUIRE(list.find(ctx, util::Any(obj)) == 5);
        }

        SECTION("does not insert new objects for dictionaries") {
            REQUIRE(list.find(ctx, util::Any(AnyDict{{"value", INT64_C(20)}})) == npos);
            REQUIRE(target->size() == 10);
        }

        SECTION("throws for object in wrong table") {
            REQUIRE_THROWS(list.find(ctx, util::Any(obj)));
        }
    }

    SECTION("get(Context)") {
        List list(r, *lv);
        CppContext ctx(r, &list.get_object_schema());

        Object obj;
        REQUIRE_NOTHROW(obj = any_cast<Object&&>(list.get(ctx, 1)));
        REQUIRE(obj.is_valid());
        REQUIRE(obj.obj().get_key() == target_keys[1]);
    }
}
