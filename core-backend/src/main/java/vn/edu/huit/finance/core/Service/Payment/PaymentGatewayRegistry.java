package vn.edu.huit.finance.core.Service.Payment;

import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Exception.InvalidRequestException;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
public class PaymentGatewayRegistry {

    private static final String MSG_UNSUPPORTED = "Cổng thanh toán không được hỗ trợ (chỉ nhận: %s)";

    private final Map<String, PaymentGateway> byName;

    public PaymentGatewayRegistry(List<PaymentGateway> gateways) {
        this.byName = gateways.stream()
                .collect(Collectors.toMap(g -> g.name().toUpperCase(), Function.identity()));
    }

    public PaymentGateway get(String provider) {
        PaymentGateway g = byName.get(provider == null ? null : provider.toUpperCase());
        if (g == null) {
            throw new InvalidRequestException(String.format(MSG_UNSUPPORTED, String.join(", ", byName.keySet())));
        }
        return g;
    }

    public boolean supports(String provider) {
        return provider != null && byName.containsKey(provider.toUpperCase());
    }
}
