# backend

Nothing here runs in production. The app talks to the results feed directly and
caches on the device; this directory is the command-line half of that contract
plus the documented path to a server-side cache if one is ever needed.

## `results_feed.py`

The same three queries the app makes, from a terminal. Useful for confirming the
feed is alive, for checking what the app *should* be showing, and as the ingest
half of the Supabase cache below.

```bash
./results_feed.py search "Pattie Wallner"     # athletes + their contact GUIDs
./results_feed.py athlete <contact-guid>      # one athlete's whole career
./results_feed.py event <event-guid>          # everyone in one race
./results_feed.py --json athlete <guid>       # raw rows
```

It reads `docs/api-config.json` from the live site first, so it breaks and gets
fixed at the same moment the app does.

## Why there is no server

The plan was a nightly crawler writing every event into Supabase, because
searching an athlete by name across hundreds of races a year has no other
answer. That turned out to be unnecessary: the results proxy accepts arbitrary
OData `$filter`, so **one request returns an athlete's entire career**, and
there is nothing for a crawler to precompute.

What a crawl would have cost: roughly 200 events a year at 1,500 finishers
each, over 20 years, is several million rows — past the free Supabase tier
before the first user, to answer a question a single live query already answers
in under a second.

## When to add one anyway

Two things would justify it, and neither has happened yet:

1. **The proxy starts rate-limiting or blocking app traffic.** A cache in front
   of it turns thousands of clients into one.
2. **Leaderboards across athletes** — "fastest bike in my age group at this race
   this decade" — which does need the data sitting somewhere queryable.

The seam is already in place. `ResultsProviding` is the protocol every screen
depends on; `ResultsAPI` is one implementation. A `CachedResultsAPI` that hits
Supabase first and falls back to the live feed is a new conformance and one line
in `LockerStore.init`, with no view changes.

Sketch of the schema, if it comes to that:

```sql
create table results (
  result_id   uuid primary key,
  contact_id  uuid not null,
  event_id    uuid not null,
  event_name  text not null,
  event_date  date,
  athlete     text not null,
  bib         int,
  age_group   text,
  swim int, t1 int, bike int, t2 int, run int, finish int,
  swim_km numeric, bike_km numeric, run_km numeric,
  rank_overall int, rank_gender int, rank_group int,
  dnf bool default false, dns bool default false, dq bool default false
);
create index on results (contact_id);
create index on results using gin (to_tsvector('simple', athlete));
```

Note the free tier allows two projects per organisation and both are currently
in use (Bond, Sports), so this would need a third project or a paid plan.

## The hotfix channel

`docs/api-config.json` is the important file in this repo. The app re-reads it
every six hours, so if the upstream URL, the proxy, or the page-size parameter
changes, publishing a new copy of that file repoints every installed app within
one launch. **Fix the feed there first; ship an app update only if the response
*shape* changes.**
