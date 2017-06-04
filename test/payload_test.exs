defmodule Kronky.PayloadTest do
  @moduledoc """
  Test conversion of changeset errors to ValidationMessage structs

  """
  use ExUnit.Case
  import Ecto.Changeset
  alias Kronky.ValidationMessage
  alias Kronky.Payload
  alias Absinthe.Resolution
  import Kronky.Payload

  def resolution(value) do
    %Resolution{
      value: value,
      adapter: "", context: "", root_value: "", schema: "", source: ""
    }
  end

  def payload(successful, messages \\ [], result \\ nil) do
    %Payload{
      successful: successful,
      messages: messages,
      result: result
    }
  end

  def assert_error_payload(messages, result) do
    assert %{value: value} = result

    expected = payload(false, messages)

    assert expected.successful == value.successful
    assert expected.result == value.result

    for message <- messages do
      message = convert_key(message)
      assert message in value.messages
    end
  end

  describe "build_payload/2" do

    test "error, validation message tuple" do
      message = %ValidationMessage{code: :required}
      resolution = resolution({:error, message})
      result = build_payload(resolution, nil)

      assert_error_payload([message], result)
    end

    test "error, string message tuple" do
      resolution = resolution({:error, "an error"})
      result = build_payload(resolution, nil)

      message = %ValidationMessage{code: :unknown, message: "an error", template: "an error"}
      assert_error_payload([message], result)
    end

    test "error list" do
      messages = [%ValidationMessage{code: :required}, %ValidationMessage{code: :max}]
      resolution = resolution({:error, messages})

      result = build_payload(resolution, nil)

      assert %{value: value} = result

      expected = payload(false, messages)
      assert expected == value
    end

    test "error changeset" do
      changeset = {%{}, %{title: :string, title_lang: :string}}
        |> Ecto.Changeset.cast(%{}, [:title, :title_lang])
        |> add_error(:title, "error 1")
        |> add_error(:title, "error 2")
        |> add_error(:title_lang, "error 3")
      resolution = resolution(changeset)

      result = build_payload(resolution, nil)

      messages = [
        %ValidationMessage{code: :unknown, message: "error 1", template: "error 1", key: :title},
        %ValidationMessage{code: :unknown, message: "error 2", template: "error 2", key: :title},
        %ValidationMessage{code: :unknown, message: "error 3", template: "error 3", key: :titleLang},
      ]

      assert_error_payload(messages, result)
    end

    test "valid changeset" do
      changeset = {%{}, %{title: :string, body: :string}}
        |> Ecto.Changeset.cast(%{}, [:title, :body])

      resolution = resolution(changeset)

      result = build_payload(resolution, nil)
      assert %{value: value} = result

      assert value.successful == true
      assert value.messages == []
      assert value.result == changeset
    end

    test "map" do
      map = %{something: "something"}
      resolution = resolution(map)

      result = build_payload(resolution, nil)
      assert %{value: value} = result

      assert value.successful == true
      assert value.messages == []
      assert value.result == map
    end

  end

end
