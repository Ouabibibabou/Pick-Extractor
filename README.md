# Client Pick Extractor

Copy the RAW originals that correspond to a client's JPEG selections. Runs on Windows with Windows PowerShell 5.1. Keep `extract-picks.bat` and `extract-picks.ps1` together.

1. Save the client's filenames in a UTF-8 `.txt` file, one per line:

   ```text
   DSC_0123.jpg
   DSC_0189
   Portrait.042.jpeg
   ```

2. Drop the list onto `extract-picks.bat`, or double-click the batch file and enter the list's path. Enter or drag in the folder containing the originals when prompted.
3. Open `Selected RAW` next to the list. It contains the copied originals and a text report for each run.

Matching uses the exact base name, ignoring case. Blank lines and repeated names are ignored. A JPEG or supported RAW extension is optional. `DSC_0123-edit.jpg` does not match `DSC_0123.NEF`. Use filenames only, not paths, wildcards, or comma-separated lists.

The search includes subfolders, but skips links, junctions, and the output folder. Supported RAW extensions: ARW, CR2, CR3, DNG, NEF, NRW, ORF, RAF, RW2, PEF, SRW. JPEGs and XMP sidecars are not copied.

Only unique matches are copied. `MISSING` means no matching RAW was found. `AMBIGUOUS` lists every candidate and copies none of them. `EXISTS` means a file already has that name in the output folder; its contents are not compared. Originals are never moved or deleted. Put lists for different jobs in separate folders to keep their outputs separate.

For unattended use, pass both paths: `extract-picks.bat "C:\Job\picks.txt" "D:\Originals"`. Exit codes: `0` all copied, `2` matches need review, `1` input, scan, or copy error.

If Windows reports that a downloaded script is not digitally signed, inspect the `.ps1` first. For a trusted copy, use **Properties > Unblock** if available. On a managed computer that requires signed scripts, follow your administrator's policy.
