-- hesent.me sign-ups: one row per attempt, to rate-limit POST /v1/public/subscribe.
-- `key` is a sha256 of the visitor's IP; the IP itself is never stored. Rows older than a day are pruned.
CREATE TABLE public_hits (
  key TEXT NOT NULL,
  at  TEXT NOT NULL
);
CREATE INDEX public_hits_at ON public_hits (at);
