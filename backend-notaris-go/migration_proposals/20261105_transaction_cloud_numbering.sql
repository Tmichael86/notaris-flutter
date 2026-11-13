-- Proposal only. Never applied automatically at server startup.
-- Counter updates must share the aggregate/receipt/outbox transaction.
CREATE TABLE transaction_cloud_number_counter (
 domain text NOT NULL CHECK(domain IN ('notaris','ppat')),
 issue_date date NOT NULL,
 last_number integer NOT NULL CHECK(last_number BETWEEN 1 AND 9999),
 PRIMARY KEY(domain,issue_date)
);
-- The eventual aggregate table MUST additionally have UNIQUE(final_number).
-- This counter proposal alone does not enable transaction CREATE.
