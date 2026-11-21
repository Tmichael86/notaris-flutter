package services

import "testing"

func TestH05SchemaSQLFormatting(t *testing.T) {
	if schemaSQL("CHECK (revision > 0)\n") != schemaSQL("CHECK(revision>0)") {
		t.Fatal("nonsemantic formatting differs")
	}
	for _, pair := range [][2]string{
		{"CHECK(x='')", "CHECK(x=' ')"},
		{"CHECK(x='superadmin')", "CHECK(x='super admin')"},
		{`CHECK("read"=1)`, `CHECK("re ad"=1)`},
		{"CHECK(x='it''s')", "CHECK(x='it'' s')"},
	} {
		if schemaSQL(pair[0]) == schemaSQL(pair[1]) {
			t.Fatal("semantic quoted whitespace was discarded")
		}
	}
}
