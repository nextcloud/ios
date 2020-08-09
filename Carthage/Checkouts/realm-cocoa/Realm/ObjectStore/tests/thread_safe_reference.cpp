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

#include "util/test_file.hpp"
#include "util/test_utils.hpp"

#include "list.hpp"
#include "object.hpp"
#include "object_schema.hpp"
#include "object_store.hpp"
#include "results.hpp"
#include "schema.hpp"
#include "thread_safe_reference.hpp"
#include "util/scheduler.hpp"

#include "impl/object_accessor_impl.hpp"

#include <realm/db.hpp>
#include <realm/history.hpp>
#include <realm/string_data.hpp>
#include <realm/util/optional.hpp>

using namespace realm;

static TableRef get_table(Realm& realm, StringData object_name) {
    return ObjectStore::table_for_object_type(realm.read_group(), object_name);
}

static Object create_object(SharedRealm const& realm, StringData object_type, AnyDict value) {
    CppContext ctx(realm);
    return Object::create(ctx, realm, object_type, util::Any(value));
}

TEST_CASE("thread safe reference") {
    using namespace std::string_literals;

    Schema schema{
        {"foo object", {
            {"ignore me", PropertyType::Int}, // Used in tests cases that don't care about the value.
        }},
        {"string object", {
            {"value", PropertyType::String|PropertyType::Nullable},
        }},
        {"int object", {
            {"value", PropertyType::Int},
        }},
        {"int array object", {
            {"value", PropertyType::Array|PropertyType::Object, "int object"}
        }},
        {"int array", {
            {"value", PropertyType::Array|PropertyType::Int}
        }},
    };

    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    SharedRealm r = Realm::get_shared_realm(config);
    r->update_schema(schema);

    // Convenience object
    r->begin_transaction();
    auto foo = create_object(r, "foo object", {{"ignore me", INT64_C(0)}});
    r->commit_transaction();

    const auto int_obj_col = r->schema().find("int object")->persisted_properties[0].column_key;

    SECTION("allowed during write transactions") {
        SECTION("obtain") {
            r->begin_transaction();
            REQUIRE_NOTHROW(ThreadSafeReference(foo));
        }
        SECTION("resolve") {
            auto ref = ThreadSafeReference(foo);
            r->begin_transaction();
            REQUIRE_NOTHROW(ref.resolve<Object>(r));
        }
    }

    SECTION("cleanup properly unpins version") {
        auto history = make_in_realm_history(config.path);
        auto shared_group = DB::create(*history, config.options());

        auto get_current_version = [&]() -> VersionID {
            auto rt = shared_group->start_read();
            auto version = rt->get_version_of_current_transaction();
            return version;
        };

        auto reference_version = get_current_version();
        auto ref = util::make_optional(ThreadSafeReference(foo));
        r->begin_transaction(); r->commit_transaction(); // Advance version

        REQUIRE(get_current_version() != reference_version); // Ensure advanced
        REQUIRE_NOTHROW(shared_group->start_read(reference_version)); // Ensure pinned

        ref = {}; // Destroy thread safe reference, unpinning version
        r->begin_transaction(); r->commit_transaction(); // Clean up old versions
        REQUIRE_THROWS(shared_group->start_read(reference_version)); // Verify unpinned
    }

    SECTION("version mismatch") {
        SECTION("resolves at older version") {
            r->begin_transaction();
            Object num = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            ColKey col = num.get_object_schema().property_for_name("value")->column_key;
            ObjKey k = num.obj().get_key();

            REQUIRE(num.obj().get<Int>(col) == 7);
            ThreadSafeReference ref;
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                Object num = Object(r2, "int object", k);
                REQUIRE(num.obj().get<Int>(col) == 7);

                r2->begin_transaction();
                num.obj().set(col, 9);
                r2->commit_transaction();

                ref = num;
            };

            REQUIRE(num.obj().get<Int>(col) == 7);
            Object num_prime = ref.resolve<Object>(r);
            REQUIRE(num_prime.obj().get<Int>(col) == 9);
            REQUIRE(num.obj().get<Int>(col) == 9);

            r->begin_transaction();
            num.obj().set(col, 11);
            r->commit_transaction();

            REQUIRE(num_prime.obj().get<Int>(col) == 11);
            REQUIRE(num.obj().get<Int>(col) == 11);
        }

        SECTION("resolve at newer version") {
            r->begin_transaction();
            Object num = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            ColKey col = num.get_object_schema().property_for_name("value")->column_key;
            ObjKey k = num.obj().get_key();

            REQUIRE(num.obj().get<Int>(col) == 7);
            auto ref = ThreadSafeReference(num);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                Object num = Object(r2, "int object", k);

                r2->begin_transaction();
                num.obj().set(col, 9);
                r2->commit_transaction();
                REQUIRE(num.obj().get<Int>(col) == 9);

                Object num_prime = ref.resolve<Object>(r2);
                REQUIRE(num_prime.obj().get<Int>(col) == 9);

                r2->begin_transaction();
                num_prime.obj().set(col, 11);
                r2->commit_transaction();

                REQUIRE(num.obj().get<Int>(col) == 11);
                REQUIRE(num_prime.obj().get<Int>(col) == 11);
            }

            REQUIRE(num.obj().get<Int>(col) == 7);
            r->refresh();
            REQUIRE(num.obj().get<Int>(col) == 11);
        }

        SECTION("resolve at newer version when schema is specified") {
            r->close();
            config.schema = schema;
            SharedRealm r = Realm::get_shared_realm(config);
            r->begin_transaction();
            Object num = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            ColKey col = num.get_object_schema().property_for_name("value")->column_key;
            auto ref = ThreadSafeReference(num);

            r->begin_transaction();
            num.obj().set(col, 9);
            r->commit_transaction();

            REQUIRE_NOTHROW(ref.resolve<Object>(r));
        }

        SECTION("resolve references at multiple versions") {
            auto commit_new_num = [&](int64_t value) -> Object {
                r->begin_transaction();
                Object num = create_object(r, "int object", {{"value", value}});
                r->commit_transaction();
                return num;
            };

            auto ref1 = ThreadSafeReference(commit_new_num(1));
            auto ref2 = ThreadSafeReference(commit_new_num(2));
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                Object num1 = ref1.resolve<Object>(r2);
                Object num2 = ref2.resolve<Object>(r2);

                ColKey col = num1.get_object_schema().property_for_name("value")->column_key;
                REQUIRE(num1.obj().get<Int>(col) == 1);
                REQUIRE(num2.obj().get<Int>(col) == 2);
            }
        }
    }

    SECTION("same thread") {
        r->begin_transaction();
        Object num = create_object(r, "int object", {{"value", INT64_C(7)}});
        r->commit_transaction();

        ColKey col = num.get_object_schema().property_for_name("value")->column_key;
        REQUIRE(num.obj().get<Int>(col) == 7);
        auto ref = ThreadSafeReference(num);
        bool did_run_section = false;

        SECTION("same realm") {
            did_run_section = true;
            {
                Object num = ref.resolve<Object>(r);
                REQUIRE(num.obj().get<Int>(col) == 7);
                r->begin_transaction();
                num.obj().set(col, 9);
                r->commit_transaction();
                REQUIRE(num.obj().get<Int>(col) == 9);
            }
            REQUIRE(num.obj().get<Int>(col) == 9);
        }
        SECTION("different realm") {
            did_run_section = true;
            {
                SharedRealm r = Realm::get_shared_realm(config);
                Object num = ref.resolve<Object>(r);
                REQUIRE(num.obj().get<Int>(col) == 7);
                r->begin_transaction();
                num.obj().set(col, 9);
                r->commit_transaction();
                REQUIRE(num.obj().get<Int>(col) == 9);
            }
            REQUIRE(num.obj().get<Int>(col) == 7);
        }
        catch2_ensure_section_run_workaround(did_run_section, "same thread", [&](){
            r->begin_transaction(); // advance to latest version by starting a write
            REQUIRE(num.obj().get<Int>(col) == 9);
            r->cancel_transaction();
        });
    }

    SECTION("passing over") {
        SECTION("objects") {
            r->begin_transaction();
            auto str = create_object(r, "string object", {});
            auto num = create_object(r, "int object", {{"value", INT64_C(0)}});
            r->commit_transaction();

            ColKey col_num = num.get_object_schema().property_for_name("value")->column_key;
            ColKey col_str = str.get_object_schema().property_for_name("value")->column_key;
            auto ref_str = ThreadSafeReference(str);
            auto ref_num = ThreadSafeReference(num);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                Object str = ref_str.resolve<Object>(r2);
                Object num = ref_num.resolve<Object>(r2);

                REQUIRE(str.obj().get<String>(col_str).is_null());
                REQUIRE(num.obj().get<Int>(col_num) == 0);

                r2->begin_transaction();
                str.obj().set(col_str, "the meaning of life");
                num.obj().set(col_num, 42);
                r2->commit_transaction();
            }

            REQUIRE(str.obj().get<String>(col_str).is_null());
            REQUIRE(num.obj().get<Int>(col_num) == 0);

            r->refresh();

            REQUIRE(str.obj().get<String>(col_str) == "the meaning of life");
            REQUIRE(num.obj().get<Int>(col_num) == 42);
        }

        SECTION("object list") {
            r->begin_transaction();
            auto zero = create_object(r, "int object", {{"value", INT64_C(0)}});
            auto obj = create_object(r, "int array object", {{"value", AnyVector{zero}}});
            auto col = get_table(*r, "int array object")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            REQUIRE(list.size() == 1);
            REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 0);
            auto ref = ThreadSafeReference(list);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                List list = ref.resolve<List>(r2);
                REQUIRE(list.size() == 1);
                REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 0);

                r2->begin_transaction();
                list.remove_all();
                auto one = create_object(r2, "int object", {{"value", INT64_C(1)}});
                auto two = create_object(r2, "int object", {{"value", INT64_C(2)}});
                list.add(one.obj());
                list.add(two.obj());
                r2->commit_transaction();

                REQUIRE(list.size() == 2);
                REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 1);
                REQUIRE(list.get(1).get<int64_t>(int_obj_col) == 2);
            }

            REQUIRE(list.size() == 1);
            REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 0);

            r->refresh();

            REQUIRE(list.size() == 2);
            REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 1);
            REQUIRE(list.get(1).get<int64_t>(int_obj_col) == 2);
        }

        SECTION("sorted object results") {
            auto& table = *get_table(*r, "string object");
            auto col = table.get_column_key("value");
            auto results = Results(r, table.where().not_equal(col, "C")).sort({{{col}}, {false}});

            r->begin_transaction();
            create_object(r, "string object", {{"value", "A"s}});
            create_object(r, "string object", {{"value", "B"s}});
            create_object(r, "string object", {{"value", "C"s}});
            create_object(r, "string object", {{"value", "D"s}});
            r->commit_transaction();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get(0).get<StringData>(col) == "D");
            REQUIRE(results.get(1).get<StringData>(col) == "B");
            REQUIRE(results.get(2).get<StringData>(col) == "A");
            auto ref = ThreadSafeReference(results);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                Results results = ref.resolve<Results>(r2);

                REQUIRE(results.size() == 3);
                REQUIRE(results.get(0).get<StringData>(col) == "D");
                REQUIRE(results.get(1).get<StringData>(col) == "B");
                REQUIRE(results.get(2).get<StringData>(col) == "A");

                r2->begin_transaction();
                results.get(2).remove();
                results.get(0).remove();
                create_object(r2, "string object", {{"value", "E"s}});
                r2->commit_transaction();

                REQUIRE(results.size() == 2);
                REQUIRE(results.get(0).get<StringData>(col) == "E");
                REQUIRE(results.get(1).get<StringData>(col) == "B");
            }

            REQUIRE(results.size() == 3);
            REQUIRE(results.get(0).get<StringData>(col) == "D");
            REQUIRE(results.get(1).get<StringData>(col) == "B");
            REQUIRE(results.get(2).get<StringData>(col) == "A");

            r->refresh();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get(0).get<StringData>(col) == "E");
            REQUIRE(results.get(1).get<StringData>(col) == "B");
        }

        SECTION("distinct object results") {
            auto& table = *get_table(*r, "string object");
            auto col = table.get_column_key("value");
            auto results = Results(r, table.where()).distinct({{{col}}}).sort({{"value", true}});

            r->begin_transaction();
            create_object(r, "string object", {{"value", "A"s}});
            create_object(r, "string object", {{"value", "A"s}});
            create_object(r, "string object", {{"value", "B"s}});
            r->commit_transaction();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get(0).get<StringData>(col) == "A");
            REQUIRE(results.get(1).get<StringData>(col) == "B");
            auto ref = ThreadSafeReference(results);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                Results results = ref.resolve<Results>(r2);

                REQUIRE(results.size() == 2);
                REQUIRE(results.get(0).get<StringData>(col) == "A");
                REQUIRE(results.get(1).get<StringData>(col) == "B");

                r2->begin_transaction();
                results.get(0).remove();
                create_object(r2, "string object", {{"value", "C"s}});
                r2->commit_transaction();

                REQUIRE(results.size() == 3);
                REQUIRE(results.get(0).get<StringData>(col) == "A");
                REQUIRE(results.get(1).get<StringData>(col) == "B");
                REQUIRE(results.get(2).get<StringData>(col) == "C");
            }

            REQUIRE(results.size() == 2);
            REQUIRE(results.get(0).get<StringData>(col) == "A");
            REQUIRE(results.get(1).get<StringData>(col) == "B");

            r->refresh();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get(0).get<StringData>(col) == "A");
            REQUIRE(results.get(1).get<StringData>(col) == "B");
            REQUIRE(results.get(2).get<StringData>(col) == "C");
        }

        SECTION("int list") {
            r->begin_transaction();
            auto obj = create_object(r, "int array", {{"value", AnyVector{INT64_C(0)}}});
            auto col = get_table(*r, "int array")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            auto ref = ThreadSafeReference(list);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                List list = ref.resolve<List>(r2);
                REQUIRE(list.size() == 1);
                REQUIRE(list.get<int64_t>(0) == 0);

                r2->begin_transaction();
                list.remove_all();
                list.add(int64_t(1));
                list.add(int64_t(2));
                r2->commit_transaction();

                REQUIRE(list.size() == 2);
                REQUIRE(list.get<int64_t>(0) == 1);
                REQUIRE(list.get<int64_t>(1) == 2);
            };

            REQUIRE(list.size() == 1);
            REQUIRE(list.get<int64_t>(0) == 0);

            r->refresh();

            REQUIRE(list.size() == 2);
            REQUIRE(list.get<int64_t>(0) == 1);
            REQUIRE(list.get<int64_t>(1) == 2);
        }

        SECTION("sorted int results") {
            r->begin_transaction();
            auto obj = create_object(r, "int array", {{"value", AnyVector{INT64_C(0), INT64_C(2), INT64_C(1)}}});
            auto col = get_table(*r, "int array")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            auto results = list.sort({{"self", true}});

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 0);
            REQUIRE(results.get<int64_t>(1) == 1);
            REQUIRE(results.get<int64_t>(2) == 2);
            auto ref = ThreadSafeReference(results);
            std::thread([ref = std::move(ref), config]() mutable {
                config.scheduler = util::Scheduler::get_frozen();
                SharedRealm r = Realm::get_shared_realm(config);
                Results results = ref.resolve<Results>(r);

                REQUIRE(results.size() == 3);
                REQUIRE(results.get<int64_t>(0) == 0);
                REQUIRE(results.get<int64_t>(1) == 1);
                REQUIRE(results.get<int64_t>(2) == 2);

                r->begin_transaction();
                auto table = get_table(*r, "int array");
                List list(r, *table->begin(), table->get_column_key("value"));
                list.remove(1);
                list.add(int64_t(-1));
                r->commit_transaction();

                REQUIRE(results.size() == 3);
                REQUIRE(results.get<int64_t>(0) == -1);
                REQUIRE(results.get<int64_t>(1) == 0);
                REQUIRE(results.get<int64_t>(2) == 1);
            }).join();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 0);
            REQUIRE(results.get<int64_t>(1) == 1);
            REQUIRE(results.get<int64_t>(2) == 2);

            r->refresh();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == -1);
            REQUIRE(results.get<int64_t>(1) == 0);
            REQUIRE(results.get<int64_t>(2) == 1);
        }

        SECTION("distinct int results") {
            r->begin_transaction();
            auto obj = create_object(
                r, "int array", {{"value", AnyVector{INT64_C(3), INT64_C(2), INT64_C(1), INT64_C(1), INT64_C(2)}}});
            auto col = get_table(*r, "int array")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            auto results = list.as_results().distinct({"self"}).sort({{"self", true}});

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 1);
            REQUIRE(results.get<int64_t>(1) == 2);
            REQUIRE(results.get<int64_t>(2) == 3);

            auto ref = ThreadSafeReference(results);
            std::thread([ref = std::move(ref), config]() mutable {
                config.scheduler = util::Scheduler::get_frozen();
                SharedRealm r = Realm::get_shared_realm(config);
                Results results = ref.resolve<Results>(r);

                REQUIRE(results.size() == 3);
                REQUIRE(results.get<int64_t>(0) == 1);
                REQUIRE(results.get<int64_t>(1) == 2);
                REQUIRE(results.get<int64_t>(2) == 3);

                r->begin_transaction();
                auto table = get_table(*r, "int array");
                List list(r, *table->begin(), table->get_column_key("value"));
                list.remove(1);
                list.remove(0);
                r->commit_transaction();

                REQUIRE(results.size() == 2);
                REQUIRE(results.get<int64_t>(0) == 1);
                REQUIRE(results.get<int64_t>(1) == 2);
            }).join();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 1);
            REQUIRE(results.get<int64_t>(1) == 2);
            REQUIRE(results.get<int64_t>(2) == 3);

            r->refresh();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get<int64_t>(0) == 1);
            REQUIRE(results.get<int64_t>(1) == 2);
        }

        SECTION("multiple types") {
            auto results = Results(r, get_table(*r, "int object")->where().equal(int_obj_col, 5));

            r->begin_transaction();
            auto num = create_object(r, "int object", {{"value", INT64_C(5)}});
            auto obj = create_object(r, "int array object", {{"value", AnyVector{}}});
            auto col = get_table(*r, "int array object")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            REQUIRE(list.size() == 0);
            REQUIRE(results.size() == 1);
            REQUIRE(results.get(0).get<int64_t>(int_obj_col) == 5);
            auto ref_num = ThreadSafeReference(num);
            auto ref_list = ThreadSafeReference(list);
            auto ref_results = ThreadSafeReference(results);
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                auto num = ref_num.resolve<Object>(r2);
                auto list = ref_list.resolve<List>(r2);
                auto results = ref_results.resolve<Results>(r2);

                REQUIRE(list.size() == 0);
                REQUIRE(results.size() == 1);
                REQUIRE(results.get(0).get<int64_t>(int_obj_col) == 5);

                r2->begin_transaction();
                num.obj().set_all(6);
                list.add(num.obj().get_key());
                r2->commit_transaction();

                REQUIRE(list.size() == 1);
                REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 6);
                REQUIRE(results.size() == 0);
            }

            REQUIRE(list.size() == 0);
            REQUIRE(results.size() == 1);
            REQUIRE(results.get(0).get<int64_t>(int_obj_col) == 5);

            r->refresh();

            REQUIRE(list.size() == 1);
            REQUIRE(list.get(0).get<int64_t>(int_obj_col) == 6);
            REQUIRE(results.size() == 0);
        }
    }

    SECTION("resolve at version where handed over thing has been deleted") {
        Object obj;
        auto delete_and_resolve = [&](auto&& list) {
            auto ref = ThreadSafeReference(list);

            r->begin_transaction();
            obj.obj().remove();
            r->commit_transaction();

            return ref.resolve<typename std::remove_reference<decltype(list)>::type>(r);
        };

        SECTION("object") {
            r->begin_transaction();
            obj = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(obj).is_valid());
        }

        SECTION("object list") {
            r->begin_transaction();
            obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
            auto col = get_table(*r, "int array object")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(list).is_valid());
        }

        SECTION("int list") {
            r->begin_transaction();
            obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
            auto col = get_table(*r, "int array")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(list).is_valid());
        }

        SECTION("object results") {
            r->begin_transaction();
            obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
            auto col = get_table(*r, "int array object")->get_column_key("value");
            List list(r, obj.obj(), col);
            r->commit_transaction();

            auto results = delete_and_resolve(list.sort({{"value", true}}));
            REQUIRE(results.is_valid());
            REQUIRE(results.size() == 0);
        }

        SECTION("int results") {
            r->begin_transaction();
            obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
            List list(r, obj.obj(), get_table(*r, "int array")->get_column_key("value"));
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(list).is_valid());
        }
    }

    SECTION("resolve at version before where handed over thing was created") {
        auto create_ref = [&](auto&& fn) -> ThreadSafeReference {
            ThreadSafeReference ref;
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                r2->begin_transaction();
                auto obj = fn(r2);
                r2->commit_transaction();
                ref = obj;
            };
            return ref;
        };

        SECTION("object") {
            auto obj = create_ref([](auto& r) {
                return create_object(r, "int object", {{"value", INT64_C(7)}});
            }).resolve<Object>(r);
            REQUIRE(obj.is_valid());
            REQUIRE(obj.get_column_value<int64_t>("value") == 7);
        }

        SECTION("object list") {
            auto list = create_ref([](auto& r) {
                auto obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
                return List(r, obj.obj(), get_table(*r, "int array object")->get_column_key("value"));
            }).resolve<List>(r);
            REQUIRE(list.is_valid());
            REQUIRE(list.size() == 1);
        }

        SECTION("int list") {
            auto list = create_ref([](auto& r) {
                auto obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
                return List(r, obj.obj(), get_table(*r, "int array")->get_column_key("value"));
            }).resolve<List>(r);
            REQUIRE(list.is_valid());
            REQUIRE(list.size() == 1);
        }

        SECTION("object results") {
            auto results = create_ref([](auto& r) {
                auto obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
                Results results = List(r, obj.obj(), get_table(*r, "int array object")->get_column_key("value"))
                    .sort({{"value", true}});
                REQUIRE(results.size() == 1);
                return results;
            }).resolve<Results>(r);
            REQUIRE(results.is_valid());
            REQUIRE(results.size() == 1);
        }

        SECTION("int results") {
            auto results = create_ref([](auto& r) {
                auto obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
                return List(r, obj.obj(), get_table(*r, "int array")->get_column_key("value")).sort({{"self", true}});
            }).resolve<Results>(r);
            REQUIRE(results.is_valid());
            REQUIRE(results.size() == 1);
        }
    }

    SECTION("create TSR inside the write transaction which created the object being handed over") {
        auto create_ref = [&](auto&& fn) -> ThreadSafeReference {
            ThreadSafeReference ref;
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                r2->begin_transaction();
                ref = fn(r2);
                r2->commit_transaction();
            };
            return ref;
        };

        SECTION("object") {
            auto obj = create_ref([](auto& r) {
                return create_object(r, "int object", {{"value", INT64_C(7)}});
            }).resolve<Object>(r);
            REQUIRE(obj.is_valid());
            REQUIRE(obj.get_column_value<int64_t>("value") == 7);
        }

        SECTION("object list") {
            auto list = create_ref([](auto& r) {
                auto obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
                return List(r, obj.obj(), get_table(*r, "int array object")->get_column_key("value"));
            }).resolve<List>(r);
            REQUIRE(list.is_valid());
            REQUIRE(list.size() == 1);
        }

        SECTION("int list") {
            auto list = create_ref([](auto& r) {
                auto obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
                return List(r, obj.obj(), get_table(*r, "int array")->get_column_key("value"));
            }).resolve<List>(r);
            REQUIRE(list.is_valid());
            REQUIRE(list.size() == 1);
        }

        SECTION("object results") {
            REQUIRE_THROWS(create_ref([](auto& r) {
                auto obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
                Results results = List(r, obj.obj(), get_table(*r, "int array object")->get_column_key("value"))
                    .sort({{"value", true}});
                REQUIRE(results.size() == 1);
                return results;
            }));
        }

        SECTION("int results") {
            auto results = create_ref([](auto& r) {
                auto obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
                return List(r, obj.obj(), get_table(*r, "int array")->get_column_key("value")).sort({{"self", true}});
            }).resolve<Results>(r);
            REQUIRE(results.is_valid());
            REQUIRE(results.size() == 1);
        }
    }

    SECTION("create TSR inside cancelled write transaction") {
        auto create_ref = [&](auto&& fn) -> ThreadSafeReference {
            ThreadSafeReference ref;
            {
                SharedRealm r2 = Realm::get_shared_realm(config);
                r2->begin_transaction();
                ref = fn(r2);
                r2->cancel_transaction();
            };
            return ref;
        };

        SECTION("object") {
            auto obj = create_ref([](auto& r) {
                return create_object(r, "int object", {{"value", INT64_C(7)}});
            }).resolve<Object>(r);
            REQUIRE_FALSE(obj.is_valid());
        }

        SECTION("object list") {
            auto list = create_ref([](auto& r) {
                auto obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
                return List(r, obj.obj(), get_table(*r, "int array object")->get_column_key("value"));
            }).resolve<List>(r);
            REQUIRE_FALSE(list.is_valid());
        }

        SECTION("int list") {
            auto list = create_ref([](auto& r) {
                auto obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
                return List(r, obj.obj(), get_table(*r, "int array")->get_column_key("value"));
            }).resolve<List>(r);
            REQUIRE_FALSE(list.is_valid());
        }

        SECTION("object results") {
            REQUIRE_THROWS(create_ref([](auto& r) {
                auto obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
                Results results = List(r, obj.obj(), get_table(*r, "int array object")->get_column_key("value"))
                    .sort({{"value", true}});
                REQUIRE(results.size() == 1);
                return results;
            }));
        }

        SECTION("int results") {
            auto results = create_ref([](auto& r) {
                auto obj = create_object(r, "int array", {{"value", AnyVector{{INT64_C(1)}}}});
                return List(r, obj.obj(), get_table(*r, "int array")->get_column_key("value")).sort({{"self", true}});
            }).resolve<Results>(r);
            REQUIRE_FALSE(results.is_valid());
        }
    }

    SECTION("lifetime") {
        SECTION("retains source realm") { // else version will become unpinned
            auto ref = ThreadSafeReference(foo);
            r = nullptr;
            r = Realm::get_shared_realm(config);
            REQUIRE_NOTHROW(ref.resolve<Object>(r));
        }
    }

    SECTION("metadata") {
        r->begin_transaction();
        auto num = create_object(r, "int object", {{"value", INT64_C(5)}});
        r->commit_transaction();
        REQUIRE(num.get_object_schema().name == "int object");

        auto ref = ThreadSafeReference(num);
        {
            SharedRealm r2 = Realm::get_shared_realm(config);
            Object num = ref.resolve<Object>(r2);
            REQUIRE(num.get_object_schema().name == "int object");
        }
    }

    SECTION("allow multiple resolves") {
        auto ref = ThreadSafeReference(foo);
        ref.resolve<Object>(r);
        REQUIRE_NOTHROW(ref.resolve<Object>(r));
    }
}
