#include <gtest/gtest.h>

namespace {

TEST(TestSuite1, Test1) {
  EXPECT_TRUE(0 == 0);
}

TEST_F(TestSuite1, Test2) {
  EXPECT_TRUE(0 == 0);
}

TEST_P(TestSuite1, Test3) {
  EXPECT_TRUE(0 == 0);
}

FRIEND_TEST(TestSuite2, Test4) {
  EXPECT_TRUE(0 == 0);
}

TYPED_TEST(TestSuite3, Test5) {
  EXPECT_TRUE(0 == 0);
}

TYPED_TEST_P(TestSuite3, Test6) {
  EXPECT_TRUE(0 == 0);
}

} // namespace
