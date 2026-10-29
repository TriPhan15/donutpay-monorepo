-- Hibernate 6.4 DDL (PostgreSQL 15, spring.jpa.hibernate.ddl-auto=create) of the 4 tables the benchmark uses.
-- Source: show-sql log of the throwaway core-backend test BenchSqlCaptureTest (see README.md); copied verbatim.
-- Entities of CODE_SHA 1cae4de. No index beyond what Hibernate creates (primary keys, unique keys).

    create table users (
        active boolean not null,
        credentials_version integer default 0 not null,
        wallet_balance numeric(38,2) not null,
        created_at timestamp(6),
        id bigserial not null,
        last_action_time timestamp(6),
        last_login_time timestamp(6),
        updated_at timestamp(6),
        ai_label varchar(50),
        email varchar(255) not null unique,
        password varchar(255) not null,
        phone varchar(255) not null unique,
        role varchar(255) not null,
        username varchar(255) not null unique,
        primary key (id)
    );

    create table categories (
        created_at timestamp(6),
        id bigserial not null,
        updated_at timestamp(6),
        name varchar(255) not null,
        type varchar(255) not null,
        primary key (id)
    );

    create table receipts (
        extracted_date date,
        extracted_total numeric(38,2),
        created_at timestamp(6),
        id bigserial not null,
        updated_at timestamp(6),
        version bigint default 0 not null,
        error_code varchar(40),
        image_url varchar(2048),
        ai_raw_data TEXT,
        status varchar(255) not null,
        vendor_name varchar(255),
        primary key (id)
    );

    create table transactions (
        amount numeric(38,2) not null,
        is_expense boolean not null,
        category_id bigint not null,
        created_at timestamp(6),
        id bigserial not null,
        receipt_id bigint unique,
        transaction_date timestamp(6) not null,
        updated_at timestamp(6),
        user_id bigint not null,
        client_id varchar(64),
        additional_images TEXT,
        category_name varchar(255),
        location varchar(255),
        note varchar(255),
        payment_method varchar(255),
        raw_receipt_data TEXT,
        status varchar(255),
        voucher_code varchar(255),
        primary key (id),
        constraint uk_transactions_user_client_id unique (user_id, client_id)
    );

alter table transactions add constraint FKsqqi7sneo04kast0o138h19mv foreign key (category_id) references categories;
alter table transactions add constraint FK7gu0iqanceg5bb779ymahu79f foreign key (receipt_id) references receipts;
alter table transactions add constraint FKqwv7rmvc8va8rep7piikrojds foreign key (user_id) references users;
