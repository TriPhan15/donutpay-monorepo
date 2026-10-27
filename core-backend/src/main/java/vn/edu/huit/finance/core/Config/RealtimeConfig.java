package vn.edu.huit.finance.core.Config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventRelay;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventSubscription;

import java.time.Duration;

/**
 * Realtime events of the admin web: every instance of the API subscribes its {@link AdminEventRelay} to the Redis channel
 * {@link AdminEventPublisher#CHANNEL}, on the same Redis (and password) as the caches. Redis stays optional: the container
 * is started by {@link AdminEventSubscription}, which keeps retrying while Redis is unreachable instead of failing the
 * start of the application.
 */
@Configuration
public class RealtimeConfig {

    /** Between two attempts to subscribe, at start-up and after Redis went away. */
    static final Duration RETRY_DELAY = Duration.ofSeconds(10);

    @Bean
    public RedisMessageListenerContainer adminEventListenerContainer(RedisConnectionFactory connectionFactory,
                                                                     AdminEventRelay relay) {
        return listenerContainer(connectionFactory, relay, RETRY_DELAY);
    }

    @Bean
    public AdminEventSubscription adminEventSubscription(RedisMessageListenerContainer adminEventListenerContainer) {
        return new AdminEventSubscription(adminEventListenerContainer, RETRY_DELAY);
    }

    /** A container for the admin channel that Spring does not start by itself (see {@link AdminEventSubscription}). */
    public static RedisMessageListenerContainer listenerContainer(RedisConnectionFactory connectionFactory,
                                                                  MessageListener listener, Duration recoveryInterval) {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer() {
            // Spring would start it with the context and fail the whole start-up when Redis is down.
            @Override
            public boolean isAutoStartup() {
                return false;
            }
        };
        container.setConnectionFactory(connectionFactory);
        container.addMessageListener(listener, new ChannelTopic(AdminEventPublisher.CHANNEL));
        container.setRecoveryInterval(recoveryInterval.toMillis());
        return container;
    }
}
