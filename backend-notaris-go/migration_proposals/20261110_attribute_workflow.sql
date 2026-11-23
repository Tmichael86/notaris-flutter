-- Additive, isolated slice. No permission grants or Transaction feed changes.
CREATE TABLE attribute_workflow_office (
 uuid uuid PRIMARY KEY
);
CREATE TABLE attribute_workflow_member (
 office_uuid uuid NOT NULL REFERENCES attribute_workflow_office(uuid),
 user_id bigint NOT NULL REFERENCES users(id),
 role text NOT NULL CHECK(role IN ('worker','reviewer')),
 PRIMARY KEY(office_uuid,user_id)
);
CREATE TABLE attribute_workflow_definition (
 uuid uuid PRIMARY KEY,
 office_uuid uuid NOT NULL REFERENCES attribute_workflow_office(uuid),
 name text NOT NULL CHECK(length(trim(name))>0),
 value_type text NOT NULL CHECK(value_type='text'),
 source_process_id text NOT NULL CHECK(length(trim(source_process_id))>0),
 UNIQUE(uuid,office_uuid)
);
CREATE TABLE attribute_workflow_item (
 process_uuid uuid PRIMARY KEY REFERENCES transaction_cloud_process(uuid),
 definition_uuid uuid NOT NULL,
 office_uuid uuid NOT NULL,
 FOREIGN KEY(definition_uuid,office_uuid) REFERENCES attribute_workflow_definition(uuid,office_uuid),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','waiting','revision','valid')),
 revision bigint NOT NULL DEFAULT 0 CHECK(revision>=0),
 version bigint NOT NULL DEFAULT 0 CHECK(version>=0),
 initialized_by bigint REFERENCES users(id),
 initialized_at timestamptz,
 submitter_id bigint REFERENCES users(id),
 CHECK ((initialized_by IS NULL)=(initialized_at IS NULL)),
 CHECK ((version=0)=(submitter_id IS NULL))
);
CREATE TABLE attribute_workflow_event (
 uuid uuid PRIMARY KEY,
 process_uuid uuid NOT NULL REFERENCES attribute_workflow_item(process_uuid),
 actor_id bigint NOT NULL REFERENCES users(id),
 request_hash text NOT NULL,
 action text NOT NULL CHECK(action IN ('initialize','submit','approve','revise')),
 revision bigint NOT NULL CHECK(revision>0),
 version bigint NOT NULL CHECK(version>=0),
 value text,
 reason text,
 occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(process_uuid,revision)
);
CREATE TABLE attribute_workflow_inbox (
 event_uuid uuid NOT NULL REFERENCES attribute_workflow_event(uuid),
 recipient_id bigint NOT NULL REFERENCES users(id),
 read_at timestamptz,
 PRIMARY KEY(recipient_id,event_uuid)
);
