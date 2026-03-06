# Critical Fixes for extract_image_layers.sh

This document contains the most critical fixes that must be applied to make the script work correctly.

## Fix #1: Subshell Exit Issue (CRITICAL)

**Location:** Lines 437-572  
**Issue:** The multi-platform loop exits only the subshell, not the main script.

### Current Code (BROKEN):
```bash
echo "$PLATFORMS" | while IFS= read -r PLATFORM; do
    if [ -n "$PLATFORM" ]; then
        # ... platform processing ...
        cd "$ORIGINAL_DIR" || exit 1
    fi
done
exit 0  # ❌ This exits the subshell, not main script!
```

### Fixed Code:
```bash
# Use process substitution instead of pipe
while IFS= read -r PLATFORM; do
    if [ -n "$PLATFORM" ]; then
        # ... platform processing ...
        cd "$ORIGINAL_DIR" || exit 1
    fi
done < <(echo "$PLATFORMS")
exit 0  # ✅ Now exits main script
```

---

## Fix #2: PLATFORM_MODE Boolean Logic (CRITICAL)

**Locations:** Lines 378, 380, 394, 606, 773, 787  
**Issue:** Incorrect boolean checking causes logic failures.

### Current Code (BROKEN):
```bash
if [ -z "$PLATFORM_MODE" ] || [ "$PLATFORM_MODE" = false ]; then
    # This condition is wrong - PLATFORM_MODE is never empty
```

### Fixed Code:
```bash
if [ "$PLATFORM_MODE" != true ]; then
    # Correct boolean check
```

### Apply to these locations:

**Line 378:**
```bash
# BEFORE:
if [ -z "$PLATFORM_MODE" ] || [ "$PLATFORM_MODE" = false ]; then

# AFTER:
if [ "$PLATFORM_MODE" != true ]; then
```

**Line 606:**
```bash
# BEFORE:
if [ "$PLATFORM_MODE" = false ] || [ -n "$SPECIFIC_PLATFORM" ]; then

# AFTER:
if [ "$PLATFORM_MODE" != true ] || [ -n "$SPECIFIC_PLATFORM" ]; then
```

**Line 773:**
```bash
# BEFORE:
if [ "$PLATFORM_MODE" = false ] || [ -n "$SPECIFIC_PLATFORM" ]; then

# AFTER:
if [ "$PLATFORM_MODE" != true ] || [ -n "$SPECIFIC_PLATFORM" ]; then
```

**Line 787:**
```bash
# BEFORE:
if [ "$EXTRACT_ALL_LAYERS" = true ] && [ "$PLATFORM_MODE" = false ]; then

# AFTER:
if [ "$EXTRACT_ALL_LAYERS" = true ] && [ "$PLATFORM_MODE" != true ]; then
```

---

## Fix #3: MERGED_DIR Undefined Variable (CRITICAL)

**Location:** Line 787  
**Issue:** Variable may not be defined if function didn't run.

### Current Code (BROKEN):
```bash
if [ "$EXTRACT_ALL_LAYERS" = true ] && [ "$PLATFORM_MODE" = false ]; then
    PrintInfo "Merged filesystem is in: $(pwd)/${MERGED_DIR}"
fi
```

### Fixed Code:
```bash
if [ "$EXTRACT_ALL_LAYERS" = true ] && [ "$PLATFORM_MODE" != true ] && [ -n "${MERGED_DIR:-}" ]; then
    PrintInfo "Merged filesystem is in: $(pwd)/${MERGED_DIR}"
fi
```

---

## Fix #4: Remove Docker Pull (CRITICAL)

**Location:** Lines 457-460  
**Issue:** Unnecessary docker pull pollutes cache and wastes time.

### Current Code (BROKEN):
```bash
# Pull platform-specific image first, then save it
PrintInfo "Pulling platform-specific image..."
if docker pull --platform "$PLATFORM" "$IMAGE_NAME" >/dev/null 2>&1; then
    PrintSuccess "Platform $PLATFORM pulled successfully"
    
    # Now save the pulled image
    if docker save "$IMAGE_NAME" -o image.tar; then
        PrintSuccess "Platform $PLATFORM saved to image.tar"
```

### Fixed Code:
```bash
# Save platform-specific image directly (no pull needed)
if docker save --platform "$PLATFORM" "$IMAGE_NAME" -o image.tar 2>/dev/null; then
    PrintSuccess "Platform $PLATFORM saved to image.tar"
```

---

## Fix #5: Direct Exit Code Checking (MAJOR)

**Locations:** Lines 165, 425, 469, 557, 625, 752  
**Issue:** Checking $? is error-prone and less readable.

### Pattern to Replace:

**BEFORE:**
```bash
docker save "$IMAGE_NAME" -o image.tar
if [ $? -eq 0 ]; then
    PrintSuccess "Image saved"
else
    PrintError "Failed"
    exit 1
fi
```

**AFTER:**
```bash
if docker save "$IMAGE_NAME" -o image.tar; then
    PrintSuccess "Image saved"
else
    PrintError "Failed"
    exit 1
fi
```

### Specific Fixes:

**Line 165:**
```bash
# BEFORE:
manifest_output=$(docker manifest inspect "$image_name" 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$manifest_output" ]; then

# AFTER:
if manifest_output=$(docker manifest inspect "$image_name" 2>/dev/null); then
```

**Line 425:**
```bash
# BEFORE:
MANIFEST_OUTPUT=$(docker manifest inspect "$IMAGE_NAME" 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$MANIFEST_OUTPUT" ]; then

# AFTER:
if MANIFEST_OUTPUT=$(docker manifest inspect "$IMAGE_NAME" 2>/dev/null); then
```

**Line 469:**
```bash
# BEFORE:
if is_macos; then
    gtar -xf image.tar 2>/dev/null || tar -xf image.tar
else
    tar -xf image.tar
fi
if [ $? -eq 0 ]; then

# AFTER:
if is_macos; then
    if gtar -xf image.tar 2>/dev/null || tar -xf image.tar; then
        PrintSuccess "Image extracted for platform $PLATFORM"
        # ... rest of code
    else
        PrintError "Failed to extract image tar for platform $PLATFORM"
    fi
else
    if tar -xf image.tar; then
        PrintSuccess "Image extracted for platform $PLATFORM"
        # ... rest of code
    else
        PrintError "Failed to extract image tar for platform $PLATFORM"
    fi
fi
```

**Line 557:**
```bash
# BEFORE:
if is_macos && command -v gtar >/dev/null 2>&1; then
    gtar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null || tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
else
    tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
fi
if [ $? -ne 0 ]; then

# AFTER:
if is_macos && command -v gtar >/dev/null 2>&1; then
    if ! gtar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null && ! tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null; then
        PrintWarning "Warning: Failed to extract layer $layer_file"
    fi
else
    if ! tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null; then
        PrintWarning "Warning: Failed to extract layer $layer_file"
    fi
fi
```

**Line 625:**
```bash
# BEFORE:
if is_macos; then
    if command -v gtar >/dev/null 2>&1; then
        PrintInfo "Using GNU tar (gtar) for extraction"
        gtar -xf image.tar 2>/dev/null || tar -xf image.tar
    else
        PrintInfo "Using BSD tar for extraction"
        tar -xf image.tar
    fi
else
    tar -xf image.tar
fi
if [ $? -eq 0 ]; then

# AFTER:
extraction_failed=false
if is_macos; then
    if command -v gtar >/dev/null 2>&1; then
        PrintInfo "Using GNU tar (gtar) for extraction"
        gtar -xf image.tar 2>/dev/null || tar -xf image.tar || extraction_failed=true
    else
        PrintInfo "Using BSD tar for extraction"
        tar -xf image.tar || extraction_failed=true
    fi
else
    tar -xf image.tar || extraction_failed=true
fi

if [ "$extraction_failed" = false ]; then
```

**Line 752:**
```bash
# BEFORE:
if is_macos && command -v gtar >/dev/null 2>&1; then
    gtar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null || tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
else
    tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
fi
if [ $? -ne 0 ]; then

# AFTER:
if is_macos && command -v gtar >/dev/null 2>&1; then
    if ! gtar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null && ! tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null; then
        PrintWarning "Warning: Failed to extract layer $layer_file"
    fi
else
    if ! tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null; then
        PrintWarning "Warning: Failed to extract layer $layer_file"
    fi
fi
```

---

## Fix #6: Add -r to Read Commands (MAJOR)

**Locations:** Lines 348, 353, 355, 359  
**Issue:** Missing -r flag can corrupt user input with backslashes.

### Pattern:
```bash
# BEFORE:
read -p "Prompt: " variable

# AFTER:
read -r -p "Prompt: " variable
```

### Specific Fixes:

**Line 348:**
```bash
read -r -p "Skip creating merged filesystem view? (y/n): " skip_merge
```

**Line 353:**
```bash
read -r -p "Extract specific platform? (y/n): " platform_choice
```

**Line 355:**
```bash
read -r -p "Enter platform (e.g., linux/amd64, linux/arm64): " SPECIFIC_PLATFORM
```

**Line 359:**
```bash
read -r -p "Remove image.tar to save space? (y/n): " cleanup
```

---

## Fix #7: Replace ls | grep (MAJOR)

**Locations:** Lines 477, 639  
**Issue:** Breaks with special filenames.

### Current Code (BROKEN):
```bash
ls -la | grep -E "(json|tar)"
```

### Fixed Code:
```bash
# Option 1: Using find
find . -maxdepth 1 \( -name "*.json" -o -name "*.tar" \) -type f -exec ls -la {} +

# Option 2: Using loop (more portable)
for file in *.json *.tar; do
    [ -e "$file" ] && ls -la "$file"
done
```

---

## Fix #8: Remove Useless Cat (MINOR)

**Locations:** Lines 482, 646, 648, 650  
**Issue:** Unnecessary process creation.

### Pattern:
```bash
# BEFORE:
cat manifest.json | jq . 2>/dev/null

# AFTER:
jq . manifest.json 2>/dev/null
```

### Specific Fixes:

**Line 482:**
```bash
python3 -m json.tool manifest.json 2>/dev/null || cat manifest.json || true
```

**Line 646:**
```bash
jq . manifest.json 2>/dev/null
```

**Line 648:**
```bash
python3 -m json.tool manifest.json 2>/dev/null
```

**Line 650:**
```bash
python -m json.tool manifest.json 2>/dev/null
```

---

## Application Order

Apply fixes in this order to avoid conflicts:

1. ✅ Fix #1: Subshell exit issue (line 437)
2. ✅ Fix #4: Remove docker pull (line 457)
3. ✅ Fix #5: All exit code checks (multiple locations)
4. ✅ Fix #2: PLATFORM_MODE boolean logic (multiple locations)
5. ✅ Fix #3: MERGED_DIR check (line 787)
6. ✅ Fix #6: read -r flags (lines 348, 353, 355, 359)
7. ✅ Fix #7: ls | grep (lines 477, 639)
8. ✅ Fix #8: useless cat (lines 482, 646, 648, 650)

---

## Testing After Fixes

Run these tests to verify the fixes:

```bash
# Test 1: Multi-platform extraction
./extract_image_layers.sh -p ubuntu:22.04

# Test 2: Specific platform
./extract_image_layers.sh -p linux/amd64 nginx:alpine

# Test 3: Single platform default
./extract_image_layers.sh alpine:latest

# Test 4: Interactive mode
./extract_image_layers.sh -i ubuntu:22.04
```

Expected results:
- Multi-platform should create separate directories for each arch
- Script should exit properly after multi-platform processing
- No undefined variable errors
- All platforms should extract correctly