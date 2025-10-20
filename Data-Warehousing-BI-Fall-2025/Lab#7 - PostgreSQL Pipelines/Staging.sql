-- schema: staging

-- drop schema if exists staging;
create schema if not exists staging
    authorization postgres;

drop schema if exists Lab7_DW;
create schema Lab7_DW;

-- staging tables
create table staging.stg_titles(
    title_id text,
    title_name text,
    author_or_director text,
    medium text,
    release_year text
);

create table staging.stg_events(
    event_id text,
    user_id text,
    title_id text,
    platform_id text,
    event_type text,
    event_ts text,
    scene_id text,
    duration_seconds text,
    sentiment_score text
);

create table staging.stg_platforms(
    platform_id text,
    platform_name text
);

create table staging.stg_event_types(
    event_type_id text,
    event_type text
);

create table staging.stg_users(
    user_id text,
    signup_date text,
    age_band text,
    country text,
    region text
);
