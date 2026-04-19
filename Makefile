.PHONY: generate build run clean export-sessions

PROJECT = Whisperbar.xcodeproj
SCHEME = Whisperbar
BUILD_DIR = .build

generate:
	which xcodegen || brew install xcodegen
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		build

run: build
	open "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}')/Whisperbar.app"

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null || true

export-sessions:
	@swift - <<'EOF'
	import Foundation
	import SQLite3

	let dbPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
	    .appendingPathComponent("Whisperbar/sessions.db").path

	var db: OpaquePointer?
	guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
	    print("Cannot open database at \(dbPath)")
	    exit(1)
	}

	var stmt: OpaquePointer?
	sqlite3_prepare_v2(db, "SELECT id,timestamp,backend,duration_ms,latency_ms,word_count,transcript,rating FROM sessions ORDER BY timestamp", -1, &stmt, nil)

	print("id,timestamp,backend,duration_ms,latency_ms,word_count,transcript,rating")
	while sqlite3_step(stmt) == SQLITE_ROW {
	    let id = sqlite3_column_int64(stmt, 0)
	    let ts = String(cString: sqlite3_column_text(stmt, 1))
	    let backend = String(cString: sqlite3_column_text(stmt, 2))
	    let dur = sqlite3_column_int(stmt, 3)
	    let lat = sqlite3_column_int(stmt, 4)
	    let words = sqlite3_column_int(stmt, 5)
	    let transcript = String(cString: sqlite3_column_text(stmt, 6)).replacingOccurrences(of: "\"", with: "\"\"")
	    let ratingPtr = sqlite3_column_text(stmt, 7)
	    let rating = ratingPtr != nil ? String(cString: ratingPtr!) : ""
	    print("\(id),\(ts),\(backend),\(dur),\(lat),\(words),\"\(transcript)\",\(rating)")
	}
	sqlite3_finalize(stmt)
	sqlite3_close(db)
	EOF
