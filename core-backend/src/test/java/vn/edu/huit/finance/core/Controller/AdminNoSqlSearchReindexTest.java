package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.ReindexInProgressException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.OcrMongoService;
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventType;
import vn.edu.huit.finance.core.Service.Search.TransactionSearchIndexer;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;


import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.flash;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The Elasticsearch half of the operations page: with {@code app.search.engine=elasticsearch} the indexer bean exists. */
@WebMvcTest(value = AdminNoSqlPageController.class, properties = "app.search.engine=elasticsearch")
@ContextConfiguration(classes = {
        AdminNoSqlPageController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminNoSqlSearchReindexTest {

    private static final String REINDEX = "/admin/nosql/search/reindex";

    @Autowired private MockMvc mockMvc;

    @MockBean private TransactionSearchIndexer indexer;
    @MockBean private OcrMongoService ocrMongoService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private UserRepository userRepo;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;
    @MockBean private AdminEventPublisher adminEventPublisher;

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpSession admin() {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
                new SecurityContextImpl(new UsernamePasswordAuthenticationToken(
                        "someone", null, AuthorityUtils.createAuthorityList(Roles.ADMIN))));
        return session;
    }

    @Test
    void thePageShowsTheEngineAndTheDocumentCountAndEnablesTheButton() throws Exception {
        when(indexer.countDocuments()).thenReturn(1234L);

        mockMvc.perform(get("/admin/nosql").session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("elasticsearch"),
                        containsString("1.234"),
                        containsString("id=\"reindexButton\""))));
    }

    @Test
    void thePageStillRendersWhenElasticsearchIsDown() throws Exception {
        when(indexer.countDocuments()).thenThrow(new DataAccessResourceFailureException("es down"));

        mockMvc.perform(get("/admin/nosql").session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Không đọc được chỉ mục Elasticsearch")));
    }

    @Test
    void reindex_redirectsWithTheCount() throws Exception {
        when(indexer.reindexAll()).thenReturn(321);

        mockMvc.perform(post(REINDEX).session(admin()))
                .andExpect(redirectedUrl("/admin/nosql"))
                .andExpect(flash().attribute("message", "Đã dựng lại chỉ mục tìm kiếm: 321 giao dịch"));
    }

    @Test
    void reindex_tellsEveryAdministratorHowManyTransactionsWereIndexed() throws Exception {
        when(indexer.reindexAll()).thenReturn(321);

        mockMvc.perform(post(REINDEX).session(admin()));

        org.mockito.ArgumentCaptor<AdminEvent> published = org.mockito.ArgumentCaptor.forClass(AdminEvent.class);
        org.mockito.Mockito.verify(adminEventPublisher).publish(published.capture());
        org.junit.jupiter.api.Assertions.assertEquals(AdminEventType.SEARCH_REINDEXED, published.getValue().type());
        org.junit.jupiter.api.Assertions.assertEquals("Đã dựng lại chỉ mục tìm kiếm: 321 giao dịch", published.getValue().message());
    }

    @Test
    void aRefusedOrFailedReindexPublishesNothing() throws Exception {
        when(indexer.reindexAll()).thenThrow(new ReindexInProgressException())
                .thenThrow(new DataAccessResourceFailureException("es down"));

        mockMvc.perform(post(REINDEX).session(admin()));
        mockMvc.perform(post(REINDEX).session(admin()));

        org.mockito.Mockito.verifyNoInteractions(adminEventPublisher);
    }

    @Test
    void reindex_elasticsearchDown_flashError() throws Exception {
        when(indexer.reindexAll()).thenThrow(new DataAccessResourceFailureException("es down"));

        mockMvc.perform(post(REINDEX).session(admin()))
                .andExpect(redirectedUrl("/admin/nosql"))
                .andExpect(flash().attribute("error", AdminNoSqlPageController.MSG_REINDEX_FAILED));
    }

    @Test
    void aReindexRefusedBecauseOneIsRunningFlashesTheWaitMessage() throws Exception {
        when(indexer.reindexAll()).thenThrow(new ReindexInProgressException());

        mockMvc.perform(post(REINDEX).session(admin()))
                .andExpect(redirectedUrl("/admin/nosql"))
                .andExpect(flash().attribute("error", "Đang dựng lại chỉ mục, vui lòng đợi"));
    }

    @Test
    void thePageDisablesTheButtonWhileTheIndexerIsRebuilding() throws Exception {
        when(indexer.isReindexing()).thenReturn(true);

        String page = mockMvc.perform(get("/admin/nosql").session(admin()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);

        assertTrue(page.replaceAll("\\s+", " ").contains("id=\"reindexButton\" type=\"submit\" class=\"btn btn-info text-white\" disabled=\"disabled\""), page);
    }
}
