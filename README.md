# User Backup Script

The **User Backup Script** is a two-part solution designed to back up a Windows user profile from **C:\Users\[Username]**. It uses a configuration file (**settings.json**) to centralize settings for remote backup locations, folder exclusion strings, and 7‑Zip compression options.

## What It Does

1. **User Profile Copying:**
   - The batch file (`_userbackup.bat`) prompts for a username and a backup server choice (Boulder or Hawaii).
   - It verifies that the profile exists in **C:\Users\[Username]**.
   - It copies key folders (Desktop, Documents, Downloads, Favorites, Links, Pictures, Videos) from **C:\Users\[Username]** into a local backup folder (`[ScriptFolder]\[Username]\Desktop_Backup`).
   - It creates a temporary exclusion file using the exclusion strings defined in **settings.json** so that any folder whose path contains `"YOUR COMPANY NAME FOR SHAREPOINT SYNCS"` or `"OneDrive"` is skipped.

2. **Compression:**
   - The batch file calls the PowerShell script (`compress.ps1`), passing the username and backup server option.
   - The PowerShell script reads **settings.json** to obtain:
     - The remote backup locations.
     - The 7‑Zip compression options (such as archive format, compression level, method, dictionary size, word size, and solid mode).
   - It checks for 7‑Zip (expected at **C:\Program Files\7‑Zip\7z.exe**). If missing, it installs 7‑Zip automatically via Chocolatey using:
   
     ```
     choco install 7zip -y
     ```
	 
   - Once 7‑Zip is available, it compresses the local backup folder into an archive named in the format **Username_Laptop.7z** (with the first two letters of the username capitalized).

3. **Remote Backup:**
   - Based on your selection, the archive is copied to one of the remote backup servers:
     - **Boulder Server:** `\\CENSORED\Usershares\User_Backup`
     - **Hawaii Server:** `\\CENSORED\UserBackup`
   - The PowerShell script creates a destination folder on the chosen remote server (named after the user with proper capitalization) if it does not exist, and then copies the archive there.
   - All actions and errors are logged to `C:\Temp\compression_log.txt`.

## Project Structure

- **settings.json**  
  Contains all configurable settings:
  - **backupLocations:** The UNC paths for the Boulder and Hawaii servers.
  - **excludeStrings:** An array of strings; any folder whose path includes one of these will be skipped.
  - **sevenZipOptions:** The options used to build the 7‑Zip command line (archive format, compression level, method, dictionary size, word size, and solid mode).

- **_userbackup.bat**  
  - Prompts for the username (the script expects the user profile at **C:\Users\[Username]**).
  - Prompts for the backup server choice.
  - Copies key folders from **C:\Users\[Username]** into a local backup folder.
  - Generates the temporary exclusion file by reading **settings.json**.
  - Calls the PowerShell script (`compress.ps1`), passing the username and backup option.

- **compress.ps1**  
  - Reads **settings.json** to get the backup server locations and 7‑Zip settings.
  - Checks for the presence of 7‑Zip (installing it via Chocolatey if necessary).
  - Compresses the local backup folder into an archive named **Username_Laptop.7z**.
  - Creates (if necessary) the destination folder on the selected remote server and copies the archive there.
  - Logs its actions to `C:\Temp\compression_log.txt`.

## How to Use

1. **Download the Scripts:**  
   Place **settings.json**, **_userbackup.bat**, and **compress.ps1** in the same directory.

2. **Run the Batch File:**  
   Double-click **_userbackup.bat** to start the process.
   - **Username Prompt:**  
     Enter the username (e.g., `JDoe` to back up **C:\Users\JDoe**).
   - **Backup Server Selection:**  
     Type `B` for Boulder Server or `H` for Hawaii Server.

3. **Execution:**  
   - The batch file copies the selected folders to a local backup folder while skipping any excluded directories.
   - It generates the temporary exclusion file from **settings.json**.
   - It then calls **compress.ps1** to:
     - Check for 7‑Zip and install it if needed.
     - Compress the local backup into an archive named **Username_Laptop.7z**.
     - Create (if necessary) the destination folder on the remote server and copy the archive there.

4. **Completion:**  
   Review the on-screen messages and check `C:\Temp\compression_log.txt` for details and any errors.

## Prerequisites

- **Windows Operating System:**  
  The scripts are designed for Windows environments.

- **Chocolatey (Optional):**  
  Required only if 7‑Zip is not installed. The script will install 7‑Zip via Chocolatey automatically if needed.

- **Network Permissions:**  
  Ensure you have the necessary permissions to access **C:\Users\[Username]** and the remote backup server locations.

## Troubleshooting

- **Configuration Issues:**  
  Verify that **settings.json** is correctly formatted and located in the same directory as the scripts.

- **7‑Zip Installation Issues:**  
  If 7‑Zip fails to install, ensure that Chocolatey is installed and you have administrative privileges.

- **Network Access:**  
  Confirm that you have access to the remote server paths and can create folders as needed.
