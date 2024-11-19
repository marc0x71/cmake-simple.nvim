local module = require("cmake-simple.lib.ts_helper")

local resources_path = vim.uv.cwd() .. "/test/resources/"

describe("Extract test details from source file", function()
  it("works with basic GTest file", function()
    local example_1 = resources_path .. "/gtest_1.cpp"

    local got = module.extract_test_details(example_1)

    assert.is.same(got["TestSuite1.Test1"], {filename = example_1, row = 5})
    assert.is.same(got["TestSuite1.Test2"], {filename = example_1, row = 9})
    assert.is.same(got["TestSuite1.Test3"], {filename = example_1, row = 13})
    assert.is.same(got["TestSuite2.Test4"], {filename = example_1, row = 17})
    assert.is.same(got["TestSuite3.Test5"], {filename = example_1, row = 21})
    assert.is.same(got["TestSuite3.Test6"], {filename = example_1, row = 25})

  end)
end)
