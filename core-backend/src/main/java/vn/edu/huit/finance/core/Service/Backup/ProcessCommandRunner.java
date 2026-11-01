package vn.edu.huit.finance.core.Service.Backup;

import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.List;
import java.util.Map;

/** Chạy công cụ ngoài bằng ProcessBuilder và đợi nó kết thúc. */
@Component
public class ProcessCommandRunner implements ExternalCommandRunner {

    @Override
    public int run(List<String> command, Map<String, String> environment) throws IOException, InterruptedException {
        ProcessBuilder processBuilder = builder(command, environment);
        processBuilder.inheritIO();
        return processBuilder.start().waitFor();
    }

    @Override
    public int runQuietly(List<String> command, Map<String, String> environment) throws IOException, InterruptedException {
        ProcessBuilder processBuilder = builder(command, environment);
        processBuilder.redirectOutput(ProcessBuilder.Redirect.DISCARD);
        processBuilder.redirectError(ProcessBuilder.Redirect.INHERIT);
        return processBuilder.start().waitFor();
    }

    private static ProcessBuilder builder(List<String> command, Map<String, String> environment) {
        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.environment().putAll(environment);
        return processBuilder;
    }
}
