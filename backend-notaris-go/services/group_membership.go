package services

// A snapshot token for membership, not a credential or group revision. Every
// supported membership/status writer shares AdminLock. Reconfirm if this changes
// between the advisory UI detail and a locked deactivation transaction.
const GroupMembershipSQL = `md5(coalesce(string_agg(m.id::text||':'||m.status::text,',' ORDER BY m.id),''))`
