-- ============================================================
-- Corporate Learning Library — Supabase Database Schema
-- 
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Books table
CREATE TABLE IF NOT EXISTS books (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  title_key   TEXT,
  author      TEXT NOT NULL,
  isbn        TEXT,
  category    TEXT,
  location    TEXT CHECK (location IN ('ACT', 'ACTS')),
  total_copies INTEGER NOT NULL DEFAULT 1,
  cover_url   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Individual physical copies of each book
CREATE TABLE IF NOT EXISTS book_copies (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id     UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  copy_number INTEGER NOT NULL DEFAULT 1,
  copy_code   TEXT UNIQUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Checkout records
CREATE TABLE IF NOT EXISTS checkouts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  copy_id         UUID NOT NULL REFERENCES book_copies(id) ON DELETE CASCADE,
  book_id         UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  borrower_name   TEXT NOT NULL,
  borrower_email  TEXT NOT NULL,
  checkout_date   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  due_date        TIMESTAMPTZ NOT NULL,
  returned_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Add location column if upgrading an existing database
-- (safe to run even if column already exists)
ALTER TABLE books ADD COLUMN IF NOT EXISTS location TEXT CHECK (location IN ('ACT', 'ACTS'));

-- Add title_key column (normalized lowercase title for grouping reviews)
ALTER TABLE books ADD COLUMN IF NOT EXISTS title_key TEXT;
UPDATE books SET title_key = LOWER(TRIM(title)) WHERE title_key IS NULL;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS title_key TEXT;
UPDATE reviews r SET title_key = (SELECT LOWER(TRIM(title)) FROM books WHERE id = r.book_id) WHERE title_key IS NULL;


-- Add copy_code to book_copies (location-prefixed, e.g. ACT-00001, ACTS-00002)
CREATE SEQUENCE IF NOT EXISTS copy_code_seq START 1;
ALTER TABLE book_copies ADD COLUMN IF NOT EXISTS copy_code TEXT UNIQUE;
CREATE OR REPLACE FUNCTION generate_copy_code() RETURNS TRIGGER AS $$
DECLARE
  loc TEXT;
BEGIN
  IF NEW.copy_code IS NULL THEN
    SELECT location INTO loc FROM books WHERE id = NEW.book_id;
    NEW.copy_code := COALESCE(loc, 'LIB') || '-' || LPAD(nextval('copy_code_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS set_copy_code ON book_copies;
CREATE TRIGGER set_copy_code BEFORE INSERT ON book_copies
  FOR EACH ROW EXECUTE FUNCTION generate_copy_code();

-- Backfill copy codes for existing copies
UPDATE book_copies bc
SET copy_code = COALESCE((SELECT location FROM books WHERE id = bc.book_id), 'LIB') || '-' || LPAD(nextval('copy_code_seq')::TEXT, 5, '0')
WHERE copy_code IS NULL;

-- Book reviews (optional, left after returning)
-- title_key groups reviews across all copies/locations of the same title
CREATE TABLE IF NOT EXISTS reviews (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id      UUID REFERENCES books(id) ON DELETE SET NULL,
  title_key    TEXT NOT NULL,
  checkout_id  UUID REFERENCES checkouts(id) ON DELETE SET NULL,
  borrower_name TEXT NOT NULL,
  rating       INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text  TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_checkouts_copy_id ON checkouts(copy_id);
CREATE INDEX IF NOT EXISTS idx_checkouts_book_id ON checkouts(book_id);
CREATE INDEX IF NOT EXISTS idx_checkouts_returned_at ON checkouts(returned_at);
CREATE INDEX IF NOT EXISTS idx_checkouts_due_date ON checkouts(due_date);
CREATE INDEX IF NOT EXISTS idx_book_copies_book_id ON book_copies(book_id);

-- ============================================================
-- Row Level Security (RLS)
-- Allow full public access since this app has no login.
-- If you want to restrict access, update these policies.
-- ============================================================

ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE book_copies ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'books' AND policyname = 'Allow all on books') THEN
    CREATE POLICY "Allow all on books" ON books FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'book_copies' AND policyname = 'Allow all on book_copies') THEN
    CREATE POLICY "Allow all on book_copies" ON book_copies FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'checkouts' AND policyname = 'Allow all on checkouts') THEN
    CREATE POLICY "Allow all on checkouts" ON checkouts FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Allow all on reviews') THEN
    CREATE POLICY "Allow all on reviews" ON reviews FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ============================================================
-- Sample data (optional — delete if not needed)
-- ============================================================

INSERT INTO books (title, author, isbn, category, location, total_copies) VALUES
  ('Atomic Habits', 'James Clear', '9780735211292', 'Personal Development', 'ACT', 2),
  ('The Lean Startup', 'Eric Ries', '9780307887894', 'Business', 'ACT', 1),
  ('Deep Work', 'Cal Newport', '9781455586691', 'Productivity', 'ACTS', 2),
  ('Designing Your Life', 'Bill Burnett & Dave Evans', '9781101875322', 'Career', 'ACTS', 1),
  ('The Five Dysfunctions of a Team', 'Patrick Lencioni', '9780787960759', 'Leadership', 'ACT', 2)
ON CONFLICT DO NOTHING;

-- Create copies for the sample books
INSERT INTO book_copies (book_id, copy_number)
SELECT id, generate_series(1, total_copies)
FROM books
WHERE NOT EXISTS (SELECT 1 FROM book_copies WHERE book_copies.book_id = books.id);
