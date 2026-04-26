#!/usr/bin/env python3
import argparse
import hashlib
import os
import sqlite3
from pathlib import Path


DEFAULT_INCLUDE_SUFFIXES = {
    ".txt",
    ".md",
    ".swift",
    ".apus",
    ".gv",
}

DEFAULT_EXCLUDE_DIRS = {
    ".git",
    ".build",
    "DerivedData",
    "Products",
}


def iter_source_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel_parts = set(path.relative_to(root).parts)
        if rel_parts & DEFAULT_EXCLUDE_DIRS:
            continue
        if path.suffix.lower() not in DEFAULT_INCLUDE_SUFFIXES:
            continue
        yield path


def split_chunks(text: str, chunk_size: int, overlap: int):
    if chunk_size <= 0:
        return []
    if overlap >= chunk_size:
        overlap = max(0, chunk_size // 4)

    chunks = []
    start = 0
    n = len(text)
    while start < n:
        end = min(n, start + chunk_size)
        chunk = text[start:end].strip()
        if chunk:
            chunks.append((start, end, chunk))
        if end == n:
            break
        start = max(start + 1, end - overlap)
    return chunks


def file_hash_and_text(path: Path):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    text = data.decode("utf-8", errors="replace")
    return digest, text


def init_db(conn: sqlite3.Connection):
    conn.executescript(
        """
        PRAGMA journal_mode=WAL;
        PRAGMA synchronous=NORMAL;

        CREATE TABLE IF NOT EXISTS docs (
            id INTEGER PRIMARY KEY,
            path TEXT NOT NULL UNIQUE,
            sha256 TEXT NOT NULL,
            size INTEGER NOT NULL,
            mtime REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY,
            doc_id INTEGER NOT NULL,
            chunk_index INTEGER NOT NULL,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            text TEXT NOT NULL,
            FOREIGN KEY(doc_id) REFERENCES docs(id) ON DELETE CASCADE
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
            text,
            path UNINDEXED,
            chunk_id UNINDEXED
        );
        """
    )


def rebuild_index(root: Path, db_path: Path, chunk_size: int, overlap: int):
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    try:
        init_db(conn)
        conn.execute("DELETE FROM chunks_fts")
        conn.execute("DELETE FROM chunks")
        conn.execute("DELETE FROM docs")

        files = sorted(iter_source_files(root))
        file_count = len(files)
        total_docs = 0
        total_chunks = 0
        bar_width = 40

        for i, path in enumerate(files, 1):
            rel = str(path.relative_to(root))
            sha256, text = file_hash_and_text(path)
            st = path.stat()
            cur = conn.execute(
                "INSERT INTO docs(path, sha256, size, mtime) VALUES (?, ?, ?, ?)",
                (rel, sha256, st.st_size, st.st_mtime),
            )
            doc_id = cur.lastrowid

            for idx, (start, end, chunk_text) in enumerate(
                split_chunks(text, chunk_size, overlap)
            ):
                c = conn.execute(
                    """
                    INSERT INTO chunks(doc_id, chunk_index, start_offset, end_offset, text)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (doc_id, idx, start, end, chunk_text),
                )
                chunk_id = c.lastrowid
                conn.execute(
                    "INSERT INTO chunks_fts(text, path, chunk_id) VALUES (?, ?, ?)",
                    (chunk_text, rel, chunk_id),
                )
                total_chunks += 1
            total_docs += 1

            filled = int(bar_width * i / file_count)
            bar = "█" * filled + "░" * (bar_width - filled)
            print(f"\r  {bar} {i}/{file_count} {rel}", end="", flush=True)

        print()
        conn.commit()
        print(f"  {total_docs} docs, {total_chunks} chunks → {db_path}")
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(
        description="Build local wiki FTS index for fast retrieval."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Project root to scan (default: current directory).",
    )
    parser.add_argument(
        "--db",
        default="wiki/index.db",
        help="SQLite DB path (default: wiki/index.db).",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=1400,
        help="Chunk size in characters (default: 1400).",
    )
    parser.add_argument(
        "--overlap",
        type=int,
        default=250,
        help="Chunk overlap in characters (default: 250).",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    db_path = Path(args.db)
    if not db_path.is_absolute():
        db_path = root / db_path

    rebuild_index(root, db_path, args.chunk_size, args.overlap)


if __name__ == "__main__":
    main()
