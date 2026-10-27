# Tài liệu tham khảo – báo cáo NoSQL nhóm 38 (đã kiểm chứng)

- Ngày kiểm chứng: **27/10/2026**. "Kiểm chứng" ghi đúng URL đã mở (WebFetch) hoặc kết quả tìm kiếm đã dùng (WebSearch).
  Số trang (pp.), DOI, ISBN chỉ ghi khi đã thấy trong nguồn đó; chỗ nào chưa xác nhận được thì ghi rõ, **không tự thêm**.
- Kiểu **IEEE**. Bài báo: `[n] A. Tác giả, "Tên bài," *Nơi XB*, vol., no., pp., năm.` Web:
  `[n] Tên, Nhà phát hành. [Online]. Available: URL (truy cập dd/mm/yyyy).`
- **Đánh số theo lần trích đầu tiên** trong báo cáo. Thứ tự dưới đây là thứ tự dự kiến (Ch.1 → Ch.4); khi viết xong
  Task 9, `check_report.py` (không `--chapter`) cảnh báo nếu thứ tự trích lần đầu không tăng dần, và mọi mục phải được
  trích ít nhất một lần. Chỉ được trích các mục trong file này; thêm tài liệu mới phải kiểm chứng như dưới đây trước.
- Thứ tự Ch.4 (sửa 28/10/2026): [21] CQRS trích lần đầu ở 4.2, [22] Spring Data Redis ở 4.3, [23] Spring Data MongoDB ở 4.4,
  [24] Spring Data Elasticsearch ở 4.5 (theo thứ tự mục 4.3 Redis → 4.4 MongoDB → 4.5 ES); [11] Compass ở 2.4.1, [13] Redis Insight
  ở 2.4.2. Các mục trích lần đầu đã ghi trong ghi chú của `outline.md`.
- Mục [3] trùng với tài liệu đã kiểm chứng của khóa luận (`docs/thesis/references.md` [5]), viết lại theo IEEE.

---

## Chương 1 – bối cảnh

[1] P. J. Sadalage and M. Fowler, *NoSQL Distilled: A Brief Guide to the Emerging World of Polyglot Persistence*. Addison-Wesley Professional, 2012.
- Kiểm chứng: https://martinfowler.com/books/nosql.html (tên, tác giả, năm 2012); WebSearch "NoSQL Distilled Sadalage Fowler Addison-Wesley 2012 ISBN 0321826620" → nhà xuất bản Addison-Wesley Professional, ISBN-10 0321826620 / ISBN-13 9780321826626 (https://www.tenlong.com.tw/products/9780321826626). Ngày phát hành chính xác các nguồn ghi khác nhau (tháng 8/2012): chỉ ghi năm.
- Dùng cho: Ch.1 (vì sao NoSQL), Ch.2 (mô hình aggregate, 4 họ NoSQL, phân tán, sharding/replication).

[2] M. Fowler, "PolyglotPersistence," martinfowler.com, 16 Nov. 2011. [Online]. Available: https://martinfowler.com/bliki/PolyglotPersistence.html (truy cập 27/10/2026).
- Kiểm chứng: https://martinfowler.com/bliki/PolyglotPersistence.html (tác giả, ngày 16/11/2011).
- Dùng cho: Ch.1 và Ch.4.1/4.2, kiến trúc nhiều CSDL (PostgreSQL + MongoDB + Redis + Elasticsearch).

[3] G. Kim, T. Hong, M. Yim, J. Nam, J. Park, J. Yim, W. Hwang, S. Yun, D. Han, and S. Park, "OCR-free document understanding transformer," in *Computer Vision – ECCV 2022* (Lecture Notes in Computer Science). Cham, Switzerland: Springer, 2022, pp. 498–517, doi: 10.1007/978-3-031-19815-1_29.
- Kiểm chứng: https://api.crossref.org/works/10.1007/978-3-031-19815-1_29 (tác giả, tên, pp. 498–517, Springer Nature Switzerland, Cham, 2022).
- Dùng cho: Ch.1 (ứng dụng có sẵn dùng AI DONUT đọc hóa đơn), Ch.3.5 (vì sao câu trả lời AI là dữ liệu bán cấu trúc, lưu bản sao phân tích ở MongoDB).

## Chương 2 – tổng quan NoSQL và GUI tool

[4] E. A. Brewer, "Towards robust distributed systems (abstract)," in *Proc. 19th Annu. ACM Symp. Principles of Distributed Computing (PODC)*, New York, NY, USA: ACM, 2000, p. 7, doi: 10.1145/343477.343502.
- Kiểm chứng: https://api.crossref.org/works/10.1145/343477.343502 (tác giả, tên, kỷ yếu, trang 7, năm 2000, ACM).
- Dùng cho: Ch.2.1, định lý CAP (phát biểu gốc).

[5] S. Gilbert and N. Lynch, "Brewer's conjecture and the feasibility of consistent, available, partition-tolerant web services," *ACM SIGACT News*, vol. 33, no. 2, pp. 51–59, 2002, doi: 10.1145/564585.564601.
- Kiểm chứng: WebSearch "Gilbert Lynch Brewer's conjecture … SIGACT News 33 2 51-59" → bản của tác giả https://www.comp.nus.edu.sg/~gilbert/pubs/BrewersConjecture-SigAct.pdf và https://www.citedrive.com/en/discovery/brewers-conjecture-and-the-feasibility-of-consistent-available-partition-tolerant-web-services (vol. 33, no. 2, pp. 51–59, DOI). Crossref (429) và dl.acm.org (403) không mở được hôm nay.
- Dùng cho: Ch.2.1, chứng minh hình thức của CAP.

[6] D. Abadi, "Consistency tradeoffs in modern distributed database system design: CAP is only part of the story," *Computer*, vol. 45, no. 2, pp. 37–42, Feb. 2012.
- Kiểm chứng: WebSearch "Abadi Consistency Tradeoffs … Computer vol 45 no 2 pp 37-42 2012" → bản của tác giả https://cs.umd.edu/~abadi/papers/abadi-pacelc.pdf (IEEE Computer, 2/2012) và bản ghi BibTeX vol. 45, no. 2, pp. 37–42. **DOI 10.1109/MC.2012.33 chưa xác nhận được** (Crossref 429, IEEE Xplore trả trang rỗng) nên không ghi DOI.
- Dùng cho: Ch.2.1 (PACELC), Ch.4.8 (bảng CAP/PACELC từng CSDL).

[7] M. Kleppmann, *Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems*. O'Reilly Media, 2017.
- Kiểm chứng: WebSearch "Kleppmann Designing Data-Intensive Applications O'Reilly Media 2017 ISBN 9781449373320" → ISBN-13 9781449373320, O'Reilly Media, 2017 (ví dụ https://hds2test.hebis.de/ulbda/Record/HEB418930597). Trang oreilly.com trả 403. Nơi xuất bản không thấy trong nguồn đã mở nên không ghi.
- Dùng cho: Ch.2.2 (replication, partitioning, mức nhất quán), Ch.4.7 (đồng bộ dữ liệu dẫn xuất, eventual consistency).

[8] Elastic, "Data in: documents and indices," in *Elasticsearch Guide [8.11]*. [Online]. Available: https://www.elastic.co/guide/en/elasticsearch/reference/8.11/documents-indices.html (truy cập 27/10/2026).
- Kiểm chứng: https://www.elastic.co/guide/en/elasticsearch/reference/8.11/documents-indices.html — "Elasticsearch is a distributed document store." và "Elasticsearch uses a data structure called an inverted index that supports very fast full-text searches."
- Dùng cho: Ch.2.3, xếp Elasticsearch ngoài 4 họ NoSQL của môn học: công cụ tìm kiếm có kho document, dựa trên chỉ mục ngược → "CSDL tự tìm hiểu".

[9] The Apache Software Foundation, *Apache Lucene Core*. [Online]. Available: https://lucene.apache.org/core/ (truy cập 27/10/2026).
- Kiểm chứng: https://lucene.apache.org/core/ — "Apache Lucene™ is a high-performance, full-featured search engine library written entirely in Java."
- Dùng cho: Ch.2.3/2.4, nền tảng Lucene (chỉ mục ngược) bên dưới Elasticsearch.

[10] MongoDB, Inc., *MongoDB Manual*. [Online]. Available: https://www.mongodb.com/docs/manual/ (truy cập 27/10/2026).
- Kiểm chứng: https://www.mongodb.com/docs/manual/ ("What is MongoDB?", Database Manual, MongoDB, Inc.). Lưu ý: trang hiện ghi bản **9.0 (current)**; https://www.mongodb.com/docs/v6.0/ cũng chuyển về bản 9.0, nên không trích được manual riêng cho 6.0 mà hệ thống chạy (`mongo:6.0`). Khi trích cú pháp, chỉ dùng tính năng có từ 6.0.
- Dùng cho: Ch.2.4 (Database/Collection/Document, embed/reference, atomic operations), Ch.4.4, Ch.5 (index, `$jsonSchema`, aggregation, explain, mongodump/mongorestore).

[11] MongoDB, Inc., "What is MongoDB Compass?" [Online]. Available: https://www.mongodb.com/docs/compass/current/ (truy cập 27/10/2026).
- Kiểm chứng: https://www.mongodb.com/docs/compass/current/ — "MongoDB Compass is a powerful GUI for querying, aggregating, and analyzing your MongoDB data in a visual environment."
- Dùng cho: **trích lần đầu ở Ch.2.4.1** (GUI tool chính thức của MongoDB, dùng ở Ch.5); Ch.5.

[12] Redis Ltd., *Redis Documentation – Develop with Redis*. [Online]. Available: https://redis.io/docs/latest/develop/ (truy cập 27/10/2026).
- Kiểm chứng: https://redis.io/docs/latest/develop/ (trang "Develop with Redis", có mục Data types: String, Hash, …); https://redis.io/docs/latest/develop/data-types/sorted-sets/ ("Redis sorted sets", ZADD O(log N)). URL cũ của khóa luận https://redis.io/docs/latest/ hôm nay trả **404**.
- Dùng cho: Ch.2.4 (String/Hash/List/Set/Sorted Set, TTL, Lua, Pub/Sub), Ch.4.3, Ch.5.

[13] Redis Ltd., "Redis Insight." [Online]. Available: https://redis.io/docs/latest/develop/tools/insight/ (truy cập 27/10/2026).
- Kiểm chứng: https://redis.io/docs/latest/develop/tools/insight/ — Browser (CRUD cho string, hash, sorted set…), CLI, Workbench, Profiler; giấy phép SSPL.
- Dùng cho: **trích lần đầu ở Ch.2.4.2** (GUI tool của Redis, dùng ở Ch.5); Ch.5.

[14] Elastic, *Elasticsearch Guide [8.11]*. [Online]. Available: https://www.elastic.co/guide/en/elasticsearch/reference/8.11/index.html (truy cập 27/10/2026).
- Kiểm chứng: https://www.elastic.co/guide/en/elasticsearch/reference/8.11/index.html ("Elasticsearch Guide [8.11] | Elastic").
- Dùng cho: Ch.2.4 (Elasticsearch), Ch.4.5 (analyzer, mapping, multi_match, fuzziness), Ch.5 (Dev Tools, snapshot/restore).

[15] Elastic, *Kibana Guide [8.11]*. [Online]. Available: https://www.elastic.co/guide/en/kibana/8.11/index.html (truy cập 27/10/2026).
- Kiểm chứng: https://www.elastic.co/guide/en/kibana/8.11/index.html ("Kibana Guide [8.11] | Elastic"); https://www.elastic.co/guide/en/kibana/8.11/introduction.html ("Kibana is a tool that helps you work with your data and navigate the Elastic Stack, from searching and analysis to management."). Trang https://www.elastic.co/guide/en/kibana/8.11/snapshot-repositories.html là trang chuyển hướng sang Elasticsearch reference.
- Dùng cho: Ch.2.5 tiêu chí 1–2 (kiến trúc, cài đặt, chức năng Kibana).

[16] Elastic, "Licensing FAQ." [Online]. Available: https://www.elastic.co/pricing/faq/licensing (truy cập 27/10/2026).
- Kiểm chứng: https://www.elastic.co/pricing/faq/licensing — mã nguồn Elasticsearch và Kibana "available under SSPL 1.0, AGPLv3, and the Elastic License v2"; bản phân phối mặc định theo Elastic License 2.0. https://www.elastic.co/subscriptions: các bậc Free and open (Basic), Platinum, Enterprise; bảng chi tiết tính năng theo bậc **không đọc được** qua WebFetch → mọi khẳng định "tính năng X có ở bản Basic" phải được chứng minh bằng ảnh chụp/đo trên stack demo (Task 4), không trích trang này. **Chưa kiểm chứng** việc AGPLv3 đã áp dụng cho bản 8.11 hay chỉ cho bản sau.
- Dùng cho: Ch.2.5 tiêu chí 3 (giấy phép Kibana trong bảng so sánh).

[17] cars10, "elasticvue," GitHub repository. [Online]. Available: https://github.com/cars10/elasticvue (truy cập 27/10/2026).
- Kiểm chứng: https://github.com/cars10/elasticvue — giấy phép **MIT**; "GUI for Elasticsearch" dạng ứng dụng desktop, tiện ích trình duyệt, Docker image, tự host; khoảng **2.8k sao** ngày 27/10/2026 (số sao thay đổi theo thời gian, ghi kèm ngày khi trích).
- Dùng cho: Ch.2.5 tiêu chí 3 (so sánh Kibana với Elasticvue: giấy phép, nền tảng, cộng đồng).

## Chương 3 – SRS

[18] *IEEE Recommended Practice for Software Requirements Specifications*, IEEE Std 830-1998, 1998.
- Kiểm chứng: WebSearch "IEEE 830-1998 Recommended Practice for Software Requirements Specifications" → https://standards.ieee.org/ieee/830/1222 (superseded standard, thay bởi ISO/IEC/IEEE 29148; phê duyệt 25/06/1998, công bố 20/10/1998). **DOI chưa xác nhận** nên không ghi.
- Dùng cho: Ch.3 (khung SRS, theo template của môn).

[19] *Systems and Software Engineering – Life Cycle Processes – Requirements Engineering*, ISO/IEC/IEEE 29148:2018, Nov. 2018.
- Kiểm chứng: WebSearch "ISO/IEC/IEEE 29148:2018 … Requirements engineering" → https://webstore.iec.ch/publication/64315 (edition 2.0, 28/11/2018, ISO/IEC JTC 1/SC 7, 92 trang). Trang iso.org không được mở trực tiếp.
- Dùng cho: Ch.3 (đặc tả yêu cầu, yêu cầu đo được ở 3.4).

## Chương 4 – SDS

[20] *IEEE Standard for Information Technology–Systems Design–Software Design Descriptions*, IEEE Std 1016-2009, 2009, doi: 10.1109/IEEESTD.2009.5167255.
- Kiểm chứng: WebSearch "IEEE 1016-2009 … Software Design Descriptions doi 10.1109/IEEESTD.2009.5167255" → https://reference.globalspec.com/standard/11002731/1016-2009 và https://www.wikipedia.org/wiki/IEEE_1016 (công bố 20/07/2009, DOI như trên, các viewpoint). Trạng thái hiện nay: nguồn ghi "Inactive – Reserved".
- Dùng cho: Ch.4 (khung SDS, các viewpoint thiết kế).

[21] M. Fowler, "CQRS," martinfowler.com, 14 Jul. 2011. [Online]. Available: https://martinfowler.com/bliki/CQRS.html (truy cập 27/10/2026).
- Kiểm chứng: https://martinfowler.com/bliki/CQRS.html (tác giả, ngày 14/07/2011; tách mô hình ghi và đọc, cảnh báo độ phức tạp).
- Dùng cho: **trích lần đầu ở Ch.4.2**, rồi 4.7, **chỉ như phép so sánh**: MongoDB là bản sao phân tích sau commit, không phải "CQRS read model".

[22] VMware, Inc., *Spring Data Redis – Reference Documentation*. [Online]. Available: https://docs.spring.io/spring-data/redis/reference/ (truy cập 27/10/2026).
- Kiểm chứng: https://docs.spring.io/spring-data/redis/reference/ — trang hiện là bản **4.1.2**; hệ thống dùng 3.2.5. Chỉ trích `RedisTemplate`/`StringRedisTemplate`, `RedisScript`, `RedisMessageListenerContainer`, `RedisCacheManager`. Nhà phát hành: dòng bản quyền "© 2008-2026 VMware, Inc." (đã mở trang này).
- Dùng cho: **trích lần đầu ở Ch.4.3** (thiết kế Redis); Ch.4.13, Ch.6.2.

[23] VMware, Inc., *Spring Data MongoDB – Reference Documentation*. [Online]. Available: https://docs.spring.io/spring-data/mongodb/reference/ (truy cập 27/10/2026).
- Kiểm chứng: https://docs.spring.io/spring-data/mongodb/reference/ — trang hiện là bản **5.1.2**; hệ thống dùng 4.2.5 (theo Spring Boot 3.2.5) và URL riêng `/reference/4.2/` trả 404. Chỉ trích các annotation có ở cả hai (`@Document`, `@Indexed`, `@CompoundIndex`, `MongoTemplate`, `Aggregation`). Nhà phát hành: mở lại chính trang này ngày 28/10/2026, dòng bản quyền của nội dung "© 2008-2026 VMware Inc." (chân trang thêm "Copyright © 2005 - Broadcom. All Rights Reserved."); ghi VMware, Inc. theo dòng đó.
- Dùng cho: **trích lần đầu ở Ch.4.4** (thiết kế MongoDB); Ch.4.12 (ánh xạ thực thể), Ch.6.2 (kết nối MongoDB).

[24] VMware, Inc., *Spring Data Elasticsearch – Reference Documentation*. [Online]. Available: https://docs.spring.io/spring-data/elasticsearch/reference/ (truy cập 27/10/2026).
- Kiểm chứng: https://docs.spring.io/spring-data/elasticsearch/reference/ — trang hiện là bản **6.1.2**, bản cũ nhất chọn được là 5.5.13; hệ thống dùng 5.2.5 (`/reference/5.2/` trả 404). Chỉ trích `@Document(createIndex=false)`, `@Setting`, `@Mapping`, `ElasticsearchOperations`, `NativeQuery`. Nhà phát hành: mở lại chính trang này ngày 28/10/2026, dòng bản quyền "© 2008-2026 VMware, Inc." (chân trang thêm "Copyright © 2005 - Broadcom. All Rights Reserved.").
- Dùng cho: **trích lần đầu ở Ch.4.5** (thiết kế Elasticsearch); Ch.4.12, Ch.6.2.

---

## Mục chưa kiểm chứng được / cần chú ý

| Mục | Vấn đề |
|---|---|
| [5] | Không mở được Crossref (429) và ACM DL (403); số liệu lấy từ PDF của tác giả + citedrive qua WebSearch. |
| [6] | DOI 10.1109/MC.2012.33 không xác nhận được → không ghi DOI. |
| [7] | Nơi xuất bản không xác nhận được → không ghi. |
| [16] | Bảng tính năng theo bậc giấy phép không đọc được; AGPL cho 8.11 chưa kiểm chứng. |
| [18] | DOI không xác nhận được → không ghi DOI. |
| [22]–[24] | Trang tham chiếu là bản mới hơn bản hệ thống dùng. Nhà phát hành "VMware, Inc." đã thấy trên **từng** trang (dòng "© 2008-2026 VMware, Inc."; chân trang ghi thêm Broadcom); không ghi nơi xuất bản. |
