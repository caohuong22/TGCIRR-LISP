$ErrorActionPreference = 'Stop'

# tools.json la nguon duy nhat cho catalog, menu va icon toolbar native.
# Tao icon truoc de gen-catalog copy dung bo BMP moi vao cac bundle.
& (Join-Path $PSScriptRoot 'gen-icons.ps1')
& (Join-Path $PSScriptRoot 'gen-catalog.ps1')
