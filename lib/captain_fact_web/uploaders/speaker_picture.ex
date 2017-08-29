defmodule CaptainFactWeb.SpeakerPicture do
  use Arc.Definition
  use Arc.Ecto.Definition

  @versions [:thumb]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  # Whitelist file extensions:
  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname |> String.downcase
    Enum.member?(@extension_whitelist, file_extension)
  end

  # Define a thumbnail transformation:
  def transform(:thumb, _) do
    {:convert, "-thumbnail 50x50^ -gravity center -extent 50x50 -format png", :png}
  end

  # Override the persisted filenames:
  def filename(version, {_, _}) do
    version
  end

  # Override the storage directory:
  def storage_dir(_, {_, speaker}) do
    "resources/speakers/#{speaker.id}"
  end
end