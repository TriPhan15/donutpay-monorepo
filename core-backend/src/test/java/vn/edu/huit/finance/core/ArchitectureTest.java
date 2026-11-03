package vn.edu.huit.finance.core;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaMethod;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import jakarta.persistence.Entity;

import java.util.Set;

import static com.tngtech.archunit.core.domain.JavaModifier.PUBLIC;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

@AnalyzeClasses(packages = ArchitectureTest.ROOT, importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    static final String ROOT = "vn.edu.huit.finance.core";
    private static final String CONTROLLER = ROOT + ".Controller..";
    private static final String REPOSITORY = ROOT + ".Repository..";
    private static final String SERVICE = ROOT + ".Service..";

    // legacy: may only shrink. Controllers that still inject a Repository directly.
    private static final Set<String> LEGACY_CONTROLLERS_USING_REPOSITORY = Set.of(
            "AdminController", "AuthController", "CategoryApiController", "PaymentController");

    // legacy: may only shrink. "Class.method" of controller methods that still return an @Entity directly.
    private static final Set<String> LEGACY_CONTROLLER_METHODS_RETURNING_ENTITY = Set.of();

    private static final Set<String> LOWERCASE_TWIN_PACKAGES =
            Set.of("controller", "service", "repository", "dto", "entity");

    private static DescribedPredicate<JavaClass> notLegacyController() {
        return DescribedPredicate.describe("are not in the legacy allowlist",
                c -> !LEGACY_CONTROLLERS_USING_REPOSITORY.contains(outermost(c).getSimpleName()));
    }

    private static JavaClass outermost(JavaClass c) {
        JavaClass current = c;
        while (current.getEnclosingClass().isPresent()) {
            current = current.getEnclosingClass().get();
        }
        return current;
    }

    @ArchTest
    static final ArchRule controllers_do_not_depend_on_repositories =
            noClasses().that().resideInAPackage(CONTROLLER).and(notLegacyController())
                    .should().dependOnClassesThat().resideInAPackage(REPOSITORY);

    @ArchTest
    static final ArchRule controllers_do_not_return_entities =
            methods().that().areDeclaredInClassesThat().resideInAPackage(CONTROLLER)
                    .and().haveModifier(PUBLIC)
                    .and(notLegacyMethod())
                    .should(new ArchCondition<JavaMethod>("not return an @Entity type") {
                        @Override
                        public void check(JavaMethod m, ConditionEvents events) {
                            boolean entity = m.getRawReturnType()
                                    .isAnnotatedWith(Entity.class);
                            if (entity) {
                                events.add(SimpleConditionEvent.violated(m,
                                        m.getFullName() + " returns entity " + m.getRawReturnType().getName()));
                            }
                        }
                    });

    private static DescribedPredicate<JavaMethod> notLegacyMethod() {
        return DescribedPredicate.describe("are not in the legacy allowlist",
                m -> !LEGACY_CONTROLLER_METHODS_RETURNING_ENTITY.contains(
                        outermost(m.getOwner()).getSimpleName() + "." + m.getName()));
    }

    @ArchTest
    static final ArchRule services_do_not_depend_on_controllers =
            noClasses().that().resideInAPackage(SERVICE)
                    .should().dependOnClassesThat().resideInAPackage(CONTROLLER);

    @ArchTest
    static final ArchRule no_lowercase_twin_packages =
            classes().should(new ArchCondition<JavaClass>("not live in a lowercase twin package") {
                @Override
                public void check(JavaClass c, ConditionEvents events) {
                    for (String part : c.getPackageName().split("\\.")) {
                        if (LOWERCASE_TWIN_PACKAGES.contains(part)) {
                            events.add(SimpleConditionEvent.violated(c,
                                    c.getName() + " lives in lowercase package '" + part + "'"));
                        }
                    }
                }
            });
}
