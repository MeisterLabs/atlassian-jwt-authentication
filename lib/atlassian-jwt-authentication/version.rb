module AtlassianJwtAuthentication
  MAJOR_VERSION = "0"
  MINOR_VERSION = "8"
  PATH_VERSION = "0"
  BUILD_NUMBER = ENV["GITHUB_SHA"] && "+#{ENV["GITHUB_SHA"][0..6]}"

  VERSION =
    (
      [
        MAJOR_VERSION,
        MINOR_VERSION,
        PATH_VERSION
      ].join(".") + BUILD_NUMBER
    ).freeze
end