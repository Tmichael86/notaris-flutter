-- Disposable proposal only. Transaction UUID is deployment-global and its domain immutable.
ALTER TABLE transaction_cloud ADD COLUMN domain text NOT NULL DEFAULT 'notaris' CHECK(domain IN ('notaris','ppat')),
 ADD UNIQUE(id,domain);
ALTER TABLE transaction_cloud_detail ALTER COLUMN pekerjaan_notaris_id DROP NOT NULL,
 ALTER COLUMN harga_id DROP NOT NULL,
 ADD COLUMN domain text NOT NULL DEFAULT 'notaris' CHECK(domain IN ('notaris','ppat')),
 ADD COLUMN pekerjaan_ppat_id bigint REFERENCES pekerjaan_ppat(id),
 ADD COLUMN harga_ppat_id bigint REFERENCES pekerjaan_ppat_harga(id),
 ADD FOREIGN KEY(transaction_id,domain) REFERENCES transaction_cloud(id,domain),
 ADD CHECK((domain='notaris' AND pekerjaan_notaris_id IS NOT NULL AND harga_id IS NOT NULL AND pekerjaan_ppat_id IS NULL AND harga_ppat_id IS NULL)
 OR (domain='ppat' AND pekerjaan_ppat_id IS NOT NULL AND harga_ppat_id IS NOT NULL AND pekerjaan_notaris_id IS NULL AND harga_id IS NULL));
