//go:build integration

package integration

import (
	"testing"
)

// TestProfileRename_FullFlow tests the complete profile rename workflow:
// 1. Create profile → get ID
// 2. Rename via PATCH using ID → get new ID
// 3. Verify accessible by new ID
// 4. Verify old ID no longer works
// 5. Verify name-based access still works (GET only)
// 6. Clean up
func TestProfileRename_FullFlow(t *testing.T) {
	// Step 1: Create profile
	code, body := httpPost(t, "/profiles/create", map[string]any{
		"name": "integration-rename-test",
	})
	if code != 200 {
		t.Fatalf("create failed: %d %s", code, string(body))
	}

	originalID := jsonField(t, body, "id")
	if originalID == "" {
		t.Fatal("no ID in create response")
	}
	t.Logf("created profile with ID: %s", originalID)

	// Step 2: Rename using ID
	code, body = httpPatch(t, "/profiles/"+originalID, map[string]any{
		"name": "integration-rename-test-renamed",
	})
	if code != 200 {
		t.Fatalf("rename failed: %d %s", code, string(body))
	}

	newID := jsonField(t, body, "id")
	newName := jsonField(t, body, "name")
	if newID == "" {
		t.Fatal("no ID in rename response")
	}
	if newName != "integration-rename-test-renamed" {
		t.Errorf("expected name 'integration-rename-test-renamed', got %q", newName)
	}
	t.Logf("renamed to %q with new ID: %s", newName, newID)

	// Step 3: Verify accessible by new ID
	code, body = httpGet(t, "/profiles/"+newID)
	if code != 200 {
		t.Errorf("GET by new ID failed: %d %s", code, string(body))
	}

	// Step 4: Verify old ID no longer works
	code, _ = httpGet(t, "/profiles/"+originalID)
	if code == 200 {
		t.Error("old ID should return 404 after rename")
	}

	// Step 5: Verify GET by name still works (read-only endpoints allow name)
	code, body = httpGet(t, "/profiles/integration-rename-test-renamed")
	if code != 200 {
		t.Errorf("GET by name failed: %d %s", code, string(body))
	}

	// Step 6: Clean up
	code, _ = httpDelete(t, "/profiles/"+newID)
	if code != 200 {
		t.Errorf("cleanup delete failed: %d", code)
	}
}

// TestProfileRename_RequiresID verifies PATCH rejects name-based paths
func TestProfileRename_RequiresID(t *testing.T) {
	// Create profile
	code, body := httpPost(t, "/profiles/create", map[string]any{
		"name": "rename-requires-id-test",
	})
	if code != 200 {
		t.Fatalf("create failed: %d %s", code, string(body))
	}
	profileID := jsonField(t, body, "id")
	defer httpDelete(t, "/profiles/"+profileID)

	// Try PATCH by name - should fail with 404
	code, body = httpPatch(t, "/profiles/rename-requires-id-test", map[string]any{
		"name": "new-name",
	})
	if code != 404 {
		t.Errorf("expected 404 when using name, got %d: %s", code, string(body))
	}

	// Verify error message is clear
	errMsg := jsonField(t, body, "error")
	if errMsg == "" {
		t.Error("expected error message in response")
	}
	t.Logf("error message: %s", errMsg)
}

// TestProfileRename_DeleteRequiresID verifies DELETE rejects name-based paths
func TestProfileRename_DeleteRequiresID(t *testing.T) {
	// Create profile
	code, body := httpPost(t, "/profiles/create", map[string]any{
		"name": "delete-requires-id-test",
	})
	if code != 200 {
		t.Fatalf("create failed: %d %s", code, string(body))
	}
	profileID := jsonField(t, body, "id")

	// Try DELETE by name - should fail with 404
	code, body = httpDelete(t, "/profiles/delete-requires-id-test")
	if code != 404 {
		t.Errorf("expected 404 when using name, got %d: %s", code, string(body))
	}

	// Clean up with ID
	httpDelete(t, "/profiles/"+profileID)
}

// TestProfileRename_ResetRequiresID verifies POST reset rejects name-based paths
func TestProfileRename_ResetRequiresID(t *testing.T) {
	// Create profile
	code, body := httpPost(t, "/profiles/create", map[string]any{
		"name": "reset-requires-id-test",
	})
	if code != 200 {
		t.Fatalf("create failed: %d %s", code, string(body))
	}
	profileID := jsonField(t, body, "id")
	defer httpDelete(t, "/profiles/"+profileID)

	// Try reset by name - should fail with 404
	code, body = httpPost(t, "/profiles/reset-requires-id-test/reset", nil)
	if code != 404 {
		t.Errorf("expected 404 when using name, got %d: %s", code, string(body))
	}

	// Reset by ID should work
	code, body = httpPost(t, "/profiles/"+profileID+"/reset", nil)
	if code != 200 {
		t.Errorf("reset by ID failed: %d %s", code, string(body))
	}
}

// TestProfileRename_Conflict verifies rename to existing name returns 409
func TestProfileRename_Conflict(t *testing.T) {
	// Create two profiles
	_, bodyA := httpPost(t, "/profiles/create", map[string]any{"name": "conflict-test-a"})
	_, bodyB := httpPost(t, "/profiles/create", map[string]any{"name": "conflict-test-b"})
	idA := jsonField(t, bodyA, "id")
	idB := jsonField(t, bodyB, "id")
	defer httpDelete(t, "/profiles/"+idA)
	defer httpDelete(t, "/profiles/"+idB)

	// Try to rename A to B's name
	code, body := httpPatch(t, "/profiles/"+idA, map[string]any{
		"name": "conflict-test-b",
	})
	if code != 409 {
		t.Errorf("expected 409 Conflict, got %d: %s", code, string(body))
	}
}

// TestProfileRename_PathTraversal verifies rename rejects malicious names
func TestProfileRename_PathTraversal(t *testing.T) {
	// Create profile
	code, body := httpPost(t, "/profiles/create", map[string]any{
		"name": "traversal-test",
	})
	if code != 200 {
		t.Fatalf("create failed: %d %s", code, string(body))
	}
	profileID := jsonField(t, body, "id")
	defer httpDelete(t, "/profiles/"+profileID)

	malicious := []string{
		"../etc/passwd",
		"..\\windows\\system32",
		"foo/../../../bar",
	}

	for _, name := range malicious {
		code, _ := httpPatch(t, "/profiles/"+profileID, map[string]any{
			"name": name,
		})
		if code == 200 {
			t.Errorf("rename to %q should have been rejected", name)
		}
	}
}
