<#
.SYNOPSIS
    Creates cline mcp.
.DESCRIPTION
    Creates cline mcp.
#>

wsl -d Ubuntu-24.04 -e bash -c '
cat > ~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/cline_mcp_settings.json << "EOF"
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/tbaltzakis"],
      "disabled": false,
      "autoApprove": []
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": ""
      },
      "disabled": true,
      "autoApprove": []
    },
    "sqlite": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sqlite", "/home/tbaltzakis/test.db"],
      "disabled": true,
      "autoApprove": []
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": ""
      },
      "disabled": true,
      "autoApprove": []
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"],
      "disabled": false,
      "autoApprove": []
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": ""
      },
      "disabled": true,
      "autoApprove": []
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
      "disabled": false,
      "autoApprove": []
    }
  }
}
EOF
echo "Created"
cat ~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/cline_mcp_settings.json
'