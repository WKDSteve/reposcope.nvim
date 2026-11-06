---@module 'reposcope.providers.gitlab.readme.readme_fetcher'
---@brief The README downloads, raw file first and the API as fallback of this provider: see `reposcope.providers.shared.readme_fetcher`.

return require("reposcope.providers.shared.readme_fetcher").new("gitlab")
