defmodule Faultline.Search.QueryTest do
  use ExUnit.Case, async: true

  alias Faultline.Search.Query

  test "parses free text and key value filters" do
    assert %Query{
             text: "TypeError checkout",
             text_terms: ["TypeError", "checkout"],
             filters: [
               {"release", "web@1.2.3"},
               {"environment", "prod"}
             ],
             reserved_filters: [],
             tag_filters: [
               {"release", "web@1.2.3"},
               {"environment", "prod"}
             ]
           } = Query.parse("release:web@1.2.3 TypeError environment:prod checkout")
  end

  test "preserves quoted filter values" do
    assert %Query{
             text: "RuntimeError",
             text_terms: ["RuntimeError"],
             filters: [{"project", "Cai Label"}, {"feature", "checkout flow"}],
             reserved_filters: [{"project", "Cai Label"}],
             tag_filters: [{"feature", "checkout flow"}]
           } = Query.parse(~s(project:"Cai Label" feature:"checkout flow" RuntimeError))
  end

  test "separates reserved filters, tag filters, and free text terms" do
    assert %Query{
             text: "TypeError checkout",
             text_terms: ["TypeError", "checkout"],
             reserved_filters: [{"project", "api"}, {"status", "unresolved"}],
             tag_filters: [{"release", "web 1"}]
           } = Query.parse(~s(project:api status:unresolved release:"web 1" TypeError checkout))
  end
end
