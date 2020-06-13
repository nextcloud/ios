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

#include "object_schema.hpp"
#include "object_store.hpp"
#include "property.hpp"
#include "schema.hpp"

#include <realm/string_data.hpp>
#include <realm/table.hpp>

using namespace realm;

TEST_CASE("ObjectStore: table_name_for_object_type()") {
    SECTION("should work with strings that aren't null-terminated") {
        auto input = StringData("good_no_bad", 4);
        auto result = ObjectStore::table_name_for_object_type(input);
        REQUIRE(result == "class_good");
    }
}

TEST_CASE("ObjectStore:: property_for_column_index()") {
    SECTION("Property should match the schema") {
        Schema schema = {
            {"object", {
                {"int", PropertyType::Int},
                {"boolNullable", PropertyType::Bool | PropertyType::Nullable},
                {"stringPK", PropertyType::String, true},
                {"dateNullableIndexed", PropertyType::Date | PropertyType::Nullable, false, true},
                {"floatNullableArray", PropertyType::Float | PropertyType::Nullable | PropertyType::Array},
                {"doubleArray", PropertyType::Double | PropertyType::Array},
                {"object", PropertyType::Object | PropertyType::Nullable, "object"},
                {"objectArray", PropertyType::Object | PropertyType::Array, "object"},
            }}
        };

        TestFile config;
        config.schema = schema;
        config.schema_version = 1;

        auto realm = Realm::get_shared_realm(config);
        ConstTableRef table = ObjectStore::table_for_object_type(realm->read_group(), "object");
        auto it = realm->schema().find("object");
        REQUIRE_FALSE(it == realm->schema().end());
        ObjectSchema object_schema = *it;

        auto all_columns = table->get_column_keys();
        for (auto col : all_columns) {
            auto property = ObjectStore::property_for_column_index(table, col);
            if (!property) {
                FAIL();
                continue;
            }
            auto actual_property = *object_schema.property_for_name(property->name);
            REQUIRE(property.value() == actual_property);
        }
   }
}
