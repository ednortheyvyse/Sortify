#!/bin/bash

# Prompt the user to select a folder using AppleScript, bringing the window to the front
folder=$(osascript -e 'tell app "Finder" to activate' -e 'POSIX path of (choose folder with prompt "Select the folder to be sorted:")')

# Check if the user cancelled the folder selection
if [ -z "$folder" ]; then
  # Display a notification using AppleScript
  osascript -e 'display notification "Selection cancelled. Exiting script." with title "File Sorter"'
  exit 0
fi

# Use the "find" command to list all non-hidden files in the folder and extract their extensions
extensions=$(find "$folder" -type f ! -name ".*" | sed 's/.*\.//' | sort -u)

# Initialize summary string
summary="These folders will be created:\n"

echo ""
echo "Number of file types to move:"

# Count the number of files with each extension and add to the summary string
for ext in $extensions; do
    count=$(find "$folder" -maxdepth 1 -type f -name "*.$ext" | wc -l)
    echo "$ext: $count"
    summary+="•   $ext:\t$count files\n"
done

# Display summary in a dialog box and check if the user clicked "Cancel"
result=$(osascript -e "try
    set the buttonList to {\"Cancel\", \"Sort\"}
    set the defaultButton to \"Sort\"
    set the cancelButton to \"Cancel\"
    set the summaryText to \"$summary\"
    set the dialogTitle to \"File Extension Summary\"
    set the userChoice to button returned of (display dialog summaryText with title dialogTitle buttons buttonList default button defaultButton cancel button cancelButton)
    return userChoice
on error number -128
    return \"Cancel\"
end try")

if [[ "$result" == "Cancel" ]]; then
    echo "User cancelled summary"
    exit 1
fi

echo ""
# Make a directory for each unique file extension, ignoring hidden files
for ext in $extensions; do
    # Check if the folder already exists
    if [ -d "${folder}${ext}" ]; then
        echo "Folder ${folder}${ext} already exists"
    else
        # Create the folder
        if mkdir "${folder}${ext}"; then
            echo "Created folder ${folder}${ext}"
        else
            echo "Error creating folder ${folder}${ext}"
            exit 1
        fi
    fi
done

echo ""
# Move all non-hidden files into the appropriate directory
if [[ -d "$folder" ]]; then
  find "$folder" -type f ! -name ".*" ! -path "$folder/*/*" | while read file; do
    if [[ -f "$file" ]]; then
      ext="${file##*.}"
      if [[ -e "$folder/$ext/${file##*/}" && ! "$file" -ef "$folder/$ext/${file##*/}" ]]; then
        mkdir -p "$folder/Unorganised"
        mv "$file" "$folder/Unorganised/"
        echo "File $file already exists in $folder/$ext. Moved to $folder/Unorganised."
      else
        mkdir -p "$folder/$ext"
        mv "$file" "$folder/$ext/"
        echo "Moved file $file to $folder/$ext"
      fi
    fi
  done
else
  echo "Folder $folder not found"
  exit 1
fi

if [[ -d "$folder/Unorganised" && $(ls -A "$folder/Unorganised") ]]; then
  osascript -e 'display notification "Sorting complete with some errors!" with title "File Sorter"'
else
  osascript -e 'display notification "Sorting complete!" with title "File Sorter"'
fi

echo "Script finished..."
exit 0


