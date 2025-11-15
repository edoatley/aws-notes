# Cursor/VS Code CloudFormation Syntax Support

This guide explains how to configure Cursor (or VS Code) to properly recognize CloudFormation YAML syntax and eliminate linting errors for intrinsic functions like `!Sub`, `!GetAtt`, etc.

## Quick Setup (3 Steps)

### Step 1: Install Recommended Extensions

1. Open Cursor/VS Code
2. Press `Cmd+Shift+X` (Mac) or `Ctrl+Shift+X` (Windows/Linux) to open Extensions
3. Search for and install these extensions:
   - **YAML** by Red Hat (`redhat.vscode-yaml`) - Essential for YAML support
   - **CloudFormation** by AWS Scripting Guy (`aws-scripting-guy.cform`) - CloudFormation-specific support
   - **AWS Toolkit** (`aws-toolkits.aws-toolkit-vscode`) - Optional but helpful

Alternatively, Cursor should prompt you to install recommended extensions when you open the workspace. Click "Install All" when prompted.

### Step 2: Reload Cursor/VS Code

After installing extensions:
- Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
- Type "Reload Window" and select it
- Or simply close and reopen Cursor

### Step 3: Verify Settings

The workspace is already configured with:
- `.vscode/settings.json` - Contains CloudFormation custom tags
- `.vscode/extensions.json` - Lists recommended extensions
- `aws-notes.code-workspace` - Workspace-level settings

## What Was Configured

### Custom Tags Recognized

The following CloudFormation intrinsic functions are now recognized:
- `!Ref` - Reference resources, parameters, etc.
- `!Sub` - String substitution
- `!GetAtt` - Get attribute from resource
- `!GetAZs` - Get availability zones
- `!Select` - Select from a list
- `!FindInMap` - Find value in mapping
- `!Base64` - Base64 encoding
- `!And`, `!Or`, `!Not`, `!Equals` - Condition functions
- `!If`, `!Transform`, `!Join`, `!Split`, `!Cidr`, `!ImportValue`

### File Associations

Files matching these patterns are treated as YAML:
- `*.yaml`
- `*.yml`
- `*.cfn`
- `template.yaml`
- `template.yml`

## Troubleshooting

### If linting errors persist:

1. **Check Extension Status:**
   - Open Extensions view (`Cmd+Shift+X`)
   - Verify "YAML" by Red Hat is installed and enabled
   - Check for any error messages

2. **Reload Window:**
   - `Cmd+Shift+P` → "Developer: Reload Window"

3. **Check Settings:**
   - `Cmd+,` to open Settings
   - Search for "yaml.customTags"
   - Verify the tags are listed

4. **Disable Conflicting Extensions:**
   - Some YAML linters may conflict
   - Try disabling other YAML-related extensions temporarily

5. **Manual Settings Override:**
   - If workspace settings don't work, add to User Settings:
   - `Cmd+Shift+P` → "Preferences: Open User Settings (JSON)"
   - Add the `yaml.customTags` array from `.vscode/settings.json`

### If errors are from a different linter:

Some linters (like YAML Schema Validator) may still show errors. You can:
- Disable schema validation for CloudFormation files
- Add this to settings:
  ```json
  "yaml.schemas": {
    "": ["template.yaml", "*.cfn"]
  }
  ```

## Verification

After setup, open `template.yaml` and verify:
- No red squiggles under `!Sub`, `!GetAtt`, `!Ref`, etc.
- IntelliSense/autocomplete works for CloudFormation resources
- Hover tooltips show information about intrinsic functions

## Additional Resources

- [CloudFormation Intrinsic Functions Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference.html)
- [YAML Extension Documentation](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)
- [CloudFormation Extension](https://marketplace.visualstudio.com/items?itemName=aws-scripting-guy.cform)


