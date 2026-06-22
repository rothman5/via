#include "greeting.h"
#include "unity.h"

/* Host unit test using the Unity framework (a git dev-dependency pinned in
   Via.lock). Tests the shared `greeting` library (a path dependency). */

void setUp(void) {}
void tearDown(void) {}

static void test_greeting_text(void)
{
    TEST_ASSERT_EQUAL_STRING("hello from Via", greeting());
}

static void test_greeting_nonempty(void)
{
    TEST_ASSERT_NOT_NULL(greeting());
    TEST_ASSERT_TRUE(greeting()[0] != '\0');
}

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_greeting_text);
    RUN_TEST(test_greeting_nonempty);
    return UNITY_END();
}
