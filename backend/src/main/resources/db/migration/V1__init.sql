-- V1__init.sql
-- Initial schema from the architecture plan ("Migracja V1").
-- Never edit this file after it is merged: add a new migration instead.

-- Lets a GiST index compare plain columns (resource_id WITH =) in appointment_no_overlap.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE business (
    id                        uuid PRIMARY KEY DEFAULT uuidv7(),
    slug                      text NOT NULL UNIQUE,
    name                      text NOT NULL,
    address                   text,
    phone                     text,
    time_zone                 text NOT NULL DEFAULT 'Europe/Warsaw',
    slot_step_minutes         int  NOT NULL DEFAULT 15 CHECK (slot_step_minutes IN (5, 10, 15, 30, 60)),
    min_lead_minutes          int  NOT NULL DEFAULT 120,
    cancellation_window_hours int  NOT NULL DEFAULT 24,
    created_at                timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    external_id text NOT NULL UNIQUE,              -- "sub" from the Keycloak token
    email       text NOT NULL UNIQUE,
    full_name   text NOT NULL,
    phone       text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE membership (
    business_id uuid NOT NULL REFERENCES business (id),
    user_id     uuid NOT NULL REFERENCES app_user (id),
    role        text NOT NULL CHECK (role IN ('OWNER', 'EMPLOYEE')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (business_id, user_id)
);

CREATE TABLE customer (
    id           uuid PRIMARY KEY DEFAULT uuidv7(),
    business_id  uuid NOT NULL REFERENCES business (id),
    user_id      uuid REFERENCES app_user (id),   -- NULL = client booked by phone, without an account
    display_name text NOT NULL,
    phone        text,
    email        text,
    notes        text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (business_id, user_id)
);

CREATE TABLE service_category (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    business_id uuid NOT NULL REFERENCES business (id),
    name        text NOT NULL,
    position    int  NOT NULL DEFAULT 0
);

CREATE TABLE service (
    id                   uuid PRIMARY KEY DEFAULT uuidv7(),
    business_id          uuid NOT NULL REFERENCES business (id),
    category_id          uuid REFERENCES service_category (id),
    name                 text NOT NULL,
    description          text,
    duration_minutes     int  NOT NULL CHECK (duration_minutes BETWEEN 5 AND 600),
    buffer_after_minutes int  NOT NULL DEFAULT 0 CHECK (buffer_after_minutes >= 0),
    price_amount         numeric(10, 2) NOT NULL CHECK (price_amount >= 0),
    currency             char(3) NOT NULL DEFAULT 'PLN',
    active               boolean NOT NULL DEFAULT true,
    position             int NOT NULL DEFAULT 0
);

CREATE TABLE resource (
    id           uuid PRIMARY KEY DEFAULT uuidv7(),
    business_id  uuid NOT NULL REFERENCES business (id),
    kind         text NOT NULL DEFAULT 'STAFF' CHECK (kind IN ('STAFF', 'ROOM')),
    user_id      uuid REFERENCES app_user (id),   -- staff member's account, if they sign in
    display_name text NOT NULL,
    active       boolean NOT NULL DEFAULT true
);

CREATE TABLE resource_service (
    resource_id uuid NOT NULL REFERENCES resource (id),
    service_id  uuid NOT NULL REFERENCES service (id),
    PRIMARY KEY (resource_id, service_id)
);

CREATE TABLE working_hours (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    resource_id uuid NOT NULL REFERENCES resource (id),
    day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- ISO: 1 = Monday
    start_time  time NOT NULL,
    end_time    time NOT NULL,
    CHECK (end_time > start_time)
);

CREATE TABLE schedule_exception (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    resource_id uuid NOT NULL REFERENCES resource (id),
    kind        text NOT NULL CHECK (kind IN ('TIME_OFF', 'EXTRA_HOURS')),
    starts_at   timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL,
    note        text,
    CHECK (ends_at > starts_at)
);

CREATE TABLE appointment (
    id              uuid PRIMARY KEY DEFAULT uuidv7(),
    business_id     uuid NOT NULL REFERENCES business (id),
    resource_id     uuid NOT NULL REFERENCES resource (id),
    service_id      uuid NOT NULL REFERENCES service (id),
    customer_id     uuid NOT NULL REFERENCES customer (id),
    starts_at       timestamptz NOT NULL,
    ends_at         timestamptz NOT NULL,           -- end of the service
    blocked_until   timestamptz NOT NULL,           -- end of the service + buffer
    during          tstzrange GENERATED ALWAYS AS (tstzrange(starts_at, blocked_until, '[)')) STORED,
    status          text NOT NULL DEFAULT 'CONFIRMED'
                    CHECK (status IN ('CONFIRMED', 'CANCELLED', 'COMPLETED', 'NO_SHOW')),
    service_name    text NOT NULL,                  -- snapshot at booking time
    price_amount    numeric(10, 2) NOT NULL,        -- price snapshot
    notes           text,
    created_by      uuid NOT NULL REFERENCES app_user (id),
    created_at      timestamptz NOT NULL DEFAULT now(),
    cancelled_by    uuid REFERENCES app_user (id),
    cancelled_at    timestamptz,
    idempotency_key text UNIQUE,                    -- from the Idempotency-Key header
    version         int NOT NULL DEFAULT 0,
    CHECK (ends_at > starts_at AND blocked_until >= ends_at),
    CONSTRAINT appointment_no_overlap
        EXCLUDE USING gist (resource_id WITH =, during WITH &&)
        WHERE (status <> 'CANCELLED')
);

CREATE INDEX appointment_business_start_idx ON appointment (business_id, starts_at);
CREATE INDEX appointment_customer_idx ON appointment (customer_id);

CREATE TABLE notification (
    id             uuid PRIMARY KEY DEFAULT uuidv7(),
    appointment_id uuid NOT NULL REFERENCES appointment (id),
    type           text NOT NULL CHECK (type IN ('CONFIRMATION', 'REMINDER', 'CANCELLATION')),
    scheduled_for  timestamptz NOT NULL,
    sent_at        timestamptz,
    attempts       int NOT NULL DEFAULT 0,
    last_error     text,
    UNIQUE (appointment_id, type)
);

CREATE INDEX notification_due_idx ON notification (scheduled_for) WHERE sent_at IS NULL;

-- Not in the plan's listing, added to follow its own rules:
-- every business table gets an index starting with business_id
-- (membership, customer and appointment already have one through their keys).
CREATE INDEX service_category_business_idx ON service_category (business_id);
CREATE INDEX service_business_idx ON service (business_id);
CREATE INDEX resource_business_idx ON resource (business_id);

-- Lookups used by the availability algorithm: resources that perform a service,
-- and the schedules and exceptions of those resources.
CREATE INDEX resource_service_service_idx ON resource_service (service_id);
CREATE INDEX working_hours_resource_idx ON working_hours (resource_id);
CREATE INDEX schedule_exception_resource_idx ON schedule_exception (resource_id, starts_at);
