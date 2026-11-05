package vn.edu.huit.finance.core.Document.Search;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.elasticsearch.annotations.DateFormat;
import org.springframework.data.elasticsearch.annotations.Document;
import org.springframework.data.elasticsearch.annotations.Field;
import org.springframework.data.elasticsearch.annotations.FieldType;
import org.springframework.data.elasticsearch.annotations.Mapping;
import org.springframework.data.elasticsearch.annotations.Setting;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.Transaction;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * One transaction as the search index holds it: a read-only copy of a PostgreSQL row (and the seller of its receipt),
 * keyed by the transaction id. PostgreSQL stays the source of truth; the index can be dropped and rebuilt from it at any
 * time. The index is never created by Spring Data on its own ({@code createIndex = false}): TransactionSearchIndexer
 * creates it from the settings and mapping files, which carry the Vietnamese folding analyzers.
 */
@Getter
@Setter
@NoArgsConstructor
@Document(indexName = TransactionSearchDocument.INDEX, createIndex = false)
@Setting(settingPath = "elasticsearch/transactions-settings.json")
@Mapping(mappingPath = "elasticsearch/transactions-mapping.json")
public class TransactionSearchDocument {

    public static final String INDEX = "transactions";

    @Id
    private String id;

    @Field(type = FieldType.Long)
    private Long userId;

    @Field(type = FieldType.Text)
    private String note;

    @Field(type = FieldType.Text)
    private String reviewNote;

    @Field(type = FieldType.Scaled_Float, scalingFactor = 10)
    private BigDecimal rating;

    @Field(type = FieldType.Text)
    private String categoryName;

    @Field(type = FieldType.Text)
    private String location;

    @Field(type = FieldType.Text)
    private String paymentMethod;

    @Field(type = FieldType.Text)
    private String vendorName;

    @Field(type = FieldType.Scaled_Float, scalingFactor = 100)
    private BigDecimal amount;

    @Field(type = FieldType.Boolean)
    private boolean expense;

    @Field(type = FieldType.Date, format = DateFormat.date_hour_minute_second_millis)
    private LocalDateTime transactionDate;

    /** The status of the receipt under the name TransactionResponseDto uses ({@link Receipt#getLegacyStatus()}); null without one. */
    @Field(type = FieldType.Keyword)
    private String receiptStatus;

    /**
     * The document of {@code t}. Reads the owner's id from the (possibly uninitialized) user proxy, which loads nothing,
     * and the receipt, so {@code t} should come from a query that fetched it (TransactionRepository.findForSearchIndex).
     */
    public static TransactionSearchDocument from(Transaction t) {
        Receipt receipt = t.getReceipt();
        TransactionSearchDocument document = new TransactionSearchDocument();
        document.setId(String.valueOf(t.getId()));
        document.setUserId(t.getUser() != null ? t.getUser().getId() : null);
        document.setNote(t.getNote());
        document.setReviewNote(t.getReviewNote());
        document.setRating(t.getRating());
        document.setCategoryName(t.getCategoryName());
        document.setLocation(t.getLocation());
        document.setPaymentMethod(t.getPaymentMethod());
        document.setVendorName(receipt != null ? receipt.getVendorName() : null);
        document.setAmount(t.getAmount());
        document.setExpense(t.isExpense());
        document.setTransactionDate(t.getTransactionDate());
        document.setReceiptStatus(receipt != null ? receipt.getLegacyStatus() : null);
        return document;
    }
}
