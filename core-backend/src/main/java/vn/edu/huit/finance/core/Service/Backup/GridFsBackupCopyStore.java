package vn.edu.huit.finance.core.Service.Backup;

import com.mongodb.client.MongoClient;
import com.mongodb.client.gridfs.model.GridFSFile;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.SimpleMongoClientDatabaseFactory;
import org.springframework.data.mongodb.core.convert.MongoConverter;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.gridfs.GridFsResource;
import org.springframework.data.mongodb.gridfs.GridFsTemplate;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Bản sao các file pg_dump trong MongoDB GridFS. Nằm trong database RIÊNG ({@value #DATABASE}), không phải finance_nosql:
 * MongoBackupService chạy mongodump cho cả finance_nosql, nên nếu các bản dump nằm ở đó thì mỗi bản sao lưu MongoDB sẽ
 * mang theo mọi bản dump PostgreSQL. Mỗi file giữ SHA-256 trong metadata; khôi phục kiểm tra lại giá trị đó.
 * <p>
 * Giới hạn: Mongo cùng máy chủ với PostgreSQL, nên bản sao này chỉ chống lỗi file hoặc ổ đĩa của PostgreSQL, không chống
 * mất cả máy chủ.
 */
@Component
public class GridFsBackupCopyStore implements BackupCopyStore {

    static final String DATABASE = "finance_backups";
    static final String BUCKET = "pg_backups";

    private static final String CONTENT_TYPE = "application/octet-stream";
    private static final String META_SHA256 = "sha256";
    private static final String META_CREATED_AT = "createdAt";
    private static final String SORT_BY_CREATED_AT = "metadata." + META_CREATED_AT;

    private final GridFsTemplate gridFs;

    public GridFsBackupCopyStore(MongoClient client, MongoConverter converter) {
        this.gridFs = new GridFsTemplate(new SimpleMongoClientDatabaseFactory(client, DATABASE), converter, BUCKET);
    }

    @Override
    public BackupCopy save(Path file, String fileName, LocalDateTime createdAt, String sha256) {
        Document metadata = new Document(META_SHA256, sha256).append(META_CREATED_AT, createdAt.toString());
        try (InputStream in = Files.newInputStream(file)) {
            ObjectId id = gridFs.store(in, fileName, CONTENT_TYPE, metadata);
            return new BackupCopy(id.toHexString(), fileName, createdAt, Files.size(file), sha256);
        } catch (IOException e) {
            throw new IllegalStateException("Could not read the backup file to copy it to MongoDB", e);
        }
    }

    @Override
    public List<BackupCopy> list() {
        List<BackupCopy> copies = new ArrayList<>();
        // The creation time is an ISO-8601 text, which sorts like the time itself.
        for (GridFSFile file : gridFs.find(new Query().with(Sort.by(Sort.Direction.DESC, SORT_BY_CREATED_AT)))) {
            copies.add(toCopy(file));
        }
        return copies;
    }

    @Override
    public void delete(String id) {
        gridFs.delete(byId(id));
    }

    @Override
    public void downloadTo(BackupCopy copy, Path target) throws IOException {
        GridFSFile file = gridFs.findOne(byId(copy.id()));
        if (file == null) {
            throw new IOException("The copy is no longer in MongoDB");
        }
        GridFsResource resource = gridFs.getResource(file);
        try (InputStream in = resource.getInputStream()) {
            Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static Query byId(String id) {
        return Query.query(Criteria.where("_id").is(new ObjectId(id)));
    }

    private static BackupCopy toCopy(GridFSFile file) {
        Document metadata = file.getMetadata();
        String createdAt = metadata == null ? null : metadata.getString(META_CREATED_AT);
        return new BackupCopy(file.getObjectId().toHexString(), file.getFilename(),
                createdAt == null ? null : LocalDateTime.parse(createdAt), file.getLength(),
                metadata == null ? null : metadata.getString(META_SHA256));
    }
}
