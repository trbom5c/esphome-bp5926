[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Branch = "main",

  [Parameter(Mandatory = $false)]
  [switch]$SkipWorkspaceCompare,

  [Parameter(Mandatory = $false)]
  [switch]$SkipGit,

  [Parameter(Mandatory = $false)]
  [switch]$SkipBootstrap,

  [Parameter(Mandatory = $false)]
  [switch]$StartDev,

  [Parameter(Mandatory = $false)]
  [switch]$SkipFrontendBootstrap,

  [Parameter(Mandatory = $false)]
  [switch]$SkipBackendBootstrap
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compareScript = Join-Path $PSScriptRoot "compare-workspace-state.ps1"
$bootstrapScript = Join-Path $PSScriptRoot "bootstrap.ps1"
$devScript = Join-Path $PSScriptRoot "dev.ps1"
$resumePromptPath = Join-Path $repoRoot ".Codex\memory\resume-prompt.md"
$resumeCheckpointPath = Join-Path $repoRoot ".Codex\memory\resume-checkpoint.md"

function Invoke-NativeOrThrow {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Description,

    [Parameter(Mandatory = $true)]
    [scriptblock]$Command
  )

  $capturedOutput = & $Command 2>&1
  if ($LASTEXITCODE -ne 0) {
    $renderedOutput = (($capturedOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
    if (
      $renderedOutput -match "FETCH_HEAD" -and
      $renderedOutput -match "Permission denied"
    ) {
      throw (
        "$Description failed because git could not update FETCH_HEAD. " +
        "This usually means the resume script is running without the permissions needed for git sync on this workstation. " +
        "Rerun the resume step with elevated git permissions, then continue. " +
        "Git output: $renderedOutput"
      )
    }

    if ($renderedOutput) {
      throw "$Description failed with exit code $LASTEXITCODE. Git output: $renderedOutput"
    }

    throw "$Description failed with exit code $LASTEXITCODE."
  }

  return $capturedOutput
}

Set-Location $repoRoot

Write-Host "Resume automation starting in $repoRoot" -ForegroundColor Cyan

if (-not $SkipWorkspaceCompare -and (Test-Path -LiteralPath $compareScript)) {
  Write-Host ""
  Write-Host "Workspace portability check:" -ForegroundColor Green
  powershell -NoProfile -ExecutionPolicy Bypass -File $compareScript
}

if (-not $SkipGit) {
  Write-Host ""
  Write-Host "Git sync:" -ForegroundColor Green

  $currentBranch = (git branch --show-current).Trim()
  if ($Branch -and $currentBranch -ne $Branch) {
    Invoke-NativeOrThrow -Description "git checkout $Branch" -Command {
      git checkout $Branch
    }
    $currentBranch = $Branch
  }

  if (-not $currentBranch) {
    throw "Could not determine the current git branch."
  }

  Invoke-NativeOrThrow -Description "git fetch origin $currentBranch" -Command {
    git fetch origin $currentBranch
  }

  Invoke-NativeOrThrow -Description "verify origin/$currentBranch exists" -Command {
    git rev-parse --verify "refs/remotes/origin/$currentBranch" | Out-Null
  }

  Invoke-NativeOrThrow -Description "fast-forward merge from origin/$currentBranch" -Command {
    git merge --ff-only "origin/$currentBranch"
  }

  $localHead = (git rev-parse HEAD).Trim()
  $remoteHead = (git rev-parse "origin/$currentBranch").Trim()
  if (-not $localHead -or -not $remoteHead) {
    throw "Could not verify local and remote HEAD after git sync."
  }
  if ($localHead -ne $remoteHead) {
    throw "Git sync verification failed. Local HEAD $localHead does not match origin/$currentBranch $remoteHead."
  }

  Write-Host "Current branch: $currentBranch" -ForegroundColor Cyan
  Write-Host "Current HEAD: $localHead" -ForegroundColor Cyan
}

if (-not $SkipBootstrap -and (Test-Path -LiteralPath $bootstrapScript)) {
  Write-Host ""
  Write-Host "Running bootstrap..." -ForegroundColor Green
  $bootstrapArgs = @()
  if ($SkipFrontendBootstrap) {
    $bootstrapArgs += "-SkipFrontend"
  }
  if ($SkipBackendBootstrap) {
    $bootstrapArgs += "-SkipBackend"
  }
  powershell -NoProfile -ExecutionPolicy Bypass -File $bootstrapScript @bootstrapArgs
}

Write-Host ""
Write-Host "Resume context:" -ForegroundColor Green
Write-Host "  Checkpoint: $resumeCheckpointPath"

if (Test-Path -LiteralPath $resumePromptPath) {
  $resumePrompt = (Get-Content -LiteralPath $resumePromptPath -Raw).Trim()
  Write-Host ""
  Write-Host "Resume prompt:" -ForegroundColor Yellow
  Write-Host $resumePrompt
}
else {
  Write-Warning "Resume prompt file not found at $resumePromptPath"
}

if ($StartDev -and (Test-Path -LiteralPath $devScript)) {
  Write-Host ""
  Write-Host "Starting development services..." -ForegroundColor Green
  powershell -NoProfile -ExecutionPolicy Bypass -File $devScript
}

Write-Host ""
Write-Host "Resume automation complete." -ForegroundColor Green
Write-Host "When ending this session, commit and push any changed repo state back to git." -ForegroundColor Yellow

