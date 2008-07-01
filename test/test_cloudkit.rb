require File.dirname(__FILE__) + '/test_helper.rb'

class TestCloudkit < Test::Unit::TestCase

  def setup
  end
  
  def test_sqlite_parser
    sqlite_mirror = CloudKit::GWT::SQLiteMirror.new(File.dirname(__FILE__) + '/fixtures/desktop_sqlite.log')
    migrations = sqlite_mirror.build_migrations
    expected = [['CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version")',
                'CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "identity_url" varchar(255) DEFAULT NULL NULL, "salt" varchar(40) DEFAULT NULL NULL, "remember_token" varchar(255) DEFAULT NULL NULL, "remember_token_expires_at" datetime DEFAULT NULL NULL, "created_at" datetime DEFAULT NULL NULL, "updated_at" datetime DEFAULT NULL NULL) ',
                'CREATE TABLE "open_id_authentication_associations" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "issued" integer DEFAULT NULL NULL, "lifetime" integer DEFAULT NULL NULL, "handle" varchar(255) DEFAULT NULL NULL, "assoc_type" varchar(255) DEFAULT NULL NULL, "server_url" blob DEFAULT NULL NULL, "secret" blob DEFAULT NULL NULL) ',
                'CREATE TABLE "open_id_authentication_nonces" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "timestamp" integer NOT NULL, "server_url" varchar(255) DEFAULT NULL NULL, "salt" varchar(255) NOT NULL) ',
                'CREATE TABLE "client_applications" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255) DEFAULT NULL NULL, "url" varchar(255) DEFAULT NULL NULL, "support_url" varchar(255) DEFAULT NULL NULL, "callback_url" varchar(255) DEFAULT NULL NULL, "key" varchar(50) DEFAULT NULL NULL, "secret" varchar(50) DEFAULT NULL NULL, "user_id" integer DEFAULT NULL NULL, "created_at" datetime DEFAULT NULL NULL, "updated_at" datetime DEFAULT NULL NULL) ',
                'CREATE unique INDEX "index_client_applications_on_key" ON "client_applications" ("key")',
                'CREATE TABLE "oauth_tokens" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer DEFAULT NULL NULL, "type" varchar(20) DEFAULT NULL NULL, "client_application_id" integer DEFAULT NULL NULL, "token" varchar(50) DEFAULT NULL NULL, "secret" varchar(50) DEFAULT NULL NULL, "authorized_at" datetime DEFAULT NULL NULL, "invalidated_at" datetime DEFAULT NULL NULL, "created_at" datetime DEFAULT NULL NULL, "updated_at" datetime DEFAULT NULL NULL) ',
                'CREATE unique INDEX "index_oauth_tokens_on_token" ON "oauth_tokens" ("token")',
                'CREATE TABLE "oauth_nonces" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "nonce" varchar(255) DEFAULT NULL NULL, "timestamp" integer DEFAULT NULL NULL, "created_at" datetime DEFAULT NULL NULL, "updated_at" datetime DEFAULT NULL NULL) ',
                'CREATE unique INDEX "index_oauth_nonces_on_nonce_and_timestamp" ON "oauth_nonces" ("nonce", "timestamp")',
                "INSERT INTO schema_migrations (version) VALUES ('1')"
                ],
                ['CREATE TABLE "action_items" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255) DEFAULT NULL NULL, "created_at" datetime DEFAULT NULL NULL, "updated_at" datetime DEFAULT NULL NULL) ',
                  "INSERT INTO schema_migrations (version) VALUES ('2')"
                ]]
    assert_equal(expected, migrations)
  end
end
