CREATE SCHEMA "app_public";
CREATE SCHEMA "app_hidden";
CREATE SCHEMA "app_private";
CREATE ROLE "example_visitor";

-- CreateEnum
CREATE TYPE "app_public"."organization_roles" AS ENUM ('ADMIN', 'MEMBER');

-- CreateTable
CREATE TABLE "app_public"."accounts" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "provider_account_id" TEXT NOT NULL,
    "refresh_token" TEXT,
    "access_token" TEXT,
    "expires_at" INTEGER,
    "token_type" TEXT,
    "scope" TEXT,
    "id_token" TEXT,
    "session_state" TEXT,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_private"."sessions" (
    "id" TEXT NOT NULL,
    "session_token" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "expires" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_public"."users" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "email" TEXT,
    "email_verified" TIMESTAMP(3),
    "image" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_private"."verification_tokens" (
    "identifier" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "expires" TIMESTAMP(3) NOT NULL
);

-- CreateTable
CREATE TABLE "app_public"."organizations" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_public"."organization_users" (
    "organization_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "role" "app_public"."organization_roles" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "organization_users_pkey" PRIMARY KEY ("organization_id","user_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "accounts_provider_provider_account_id_key" ON "app_public"."accounts"("provider", "provider_account_id");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_session_token_key" ON "app_private"."sessions"("session_token");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "app_public"."users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "verification_tokens_token_key" ON "app_private"."verification_tokens"("token");

-- CreateIndex
CREATE UNIQUE INDEX "verification_tokens_identifier_token_key" ON "app_private"."verification_tokens"("identifier", "token");

-- CreateIndex
CREATE INDEX "organization_users_user_id_idx" ON "app_public"."organization_users"("user_id");

-- CreateIndex
CREATE INDEX "organization_users_organization_id_idx" ON "app_public"."organization_users"("organization_id");

-- AddForeignKey
ALTER TABLE "app_public"."accounts" ADD CONSTRAINT "accounts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app_public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app_private"."sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app_public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app_public"."organization_users" ADD CONSTRAINT "organization_users_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "app_public"."organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app_public"."organization_users" ADD CONSTRAINT "organization_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app_public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Custom
GRANT USAGE ON SCHEMA "app_public" TO "example_visitor";

-- User policies
ALTER TABLE "app_public"."users" ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all on "app_public"."users" FOR SELECT USING (true);
GRANT SELECT ON "app_public"."users" TO "example_visitor";

-- Organization policies
ALTER TABLE "app_public"."organizations" ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all on "app_public"."organizations" FOR SELECT USING (true);
GRANT SELECT ON "app_public"."organizations" TO "example_visitor";

-- Organization policies
ALTER TABLE "app_public"."organization_users" ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all on "app_public"."organization_users" FOR SELECT USING (true);
GRANT SELECT ON "app_public"."organization_users" TO "example_visitor";

-- Current user id
CREATE FUNCTION "app_public"."current_user_id"() RETURNS TEXT AS $$
  SELECT nullif(current_setting('jwt.claims.user_id', true), '')::TEXT;
$$ LANGUAGE SQL STABLE SET search_path FROM current;

COMMENT ON FUNCTION "app_public"."current_user_id"() IS $$
@behavior -*
Handy method to get the current user ID for use in RLS policies, etc; in GraphQL, use `currentUser{id}` instead.
$$;

-- Current user
CREATE FUNCTION "app_public"."current_user"() RETURNS "app_public"."users" AS $$
  SELECT "users".* from "app_public"."users" WHERE "id" = "app_public"."current_user_id"();
$$ LANGUAGE SQL STABLE SET search_path FROM current;

-- Rename to Organization.users
COMMENT ON CONSTRAINT "organization_users_organization_id_fkey" ON "app_public"."organization_users" IS $$
@foreignConnectionFieldName users
$$;

-- Rename to User.organizations
COMMENT ON CONSTRAINT "organization_users_user_id_fkey" ON "app_public"."organization_users" IS $$
@foreignConnectionFieldName organizations
$$;

-- Remove organizationUsers from root
COMMENT ON TABLE "app_public"."organization_users" IS $$
@behavior -query:resource:connection -query:resource:single
$$;
