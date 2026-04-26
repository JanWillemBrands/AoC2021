#!/usr/bin/env python3
import argparse
import sqlite3
from pathlib import Path


def query(db_path: Path, text: str, limit: int):
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            """
            SELECT
                f.path AS path,
                c.chunk_index AS chunk_index,
                bm25(chunks_fts) AS score,
                snippet(chunks_fts, 0, '[', ']', ' ... ', 18) AS snippet
            FROM chunks_fts
            JOIN chunks c ON c.id = chunks_fts.chunk_id
            JOIN docs f ON f.id = c.doc_id
            WHERE chunks_fts MATCH ?
            ORDER BY score
            LIMIT ?
            """,
            (text, limit),
        ).fetchall()
        return rows
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Query local wiki index.")
    parser.add_argument("query", help="Search query. Use FTS syntax if needed.")
    parser.add_argument(
        "--db",
        default="wiki/index.db",
        help="SQLite DB path (default: wiki/index.db).",
    )
    parser.add_argument("--top", type=int, default=8, help="Number of hits (default: 8).")
    args = parser.parse_args()

    db_path = Path(args.db).resolve()
    if not db_path.exists():
        raise SystemExit(f"Index not found: {db_path}. Run build_wiki.py first.")

    rows = query(db_path, args.query, args.top)
    if not rows:
        print("No hits.")
        return

    for i, row in enumerate(rows, start=1):
        print(f"{i}. {row['path']} (chunk {row['chunk_index']}, score {row['score']:.3f})")
        print(f"   {row['snippet']}")


if __name__ == "__main__":
    main()
