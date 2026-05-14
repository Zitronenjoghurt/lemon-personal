---
title: "Dev Diary - Entry #2"
date: 2026-05-14T16:15:26+02:00
featureImage: https://media.lemon.industries/screenshot-20260514180636.png
draft: false
description: "A dev diary entry where I talk about progress in multi-threadding and establishing an SSH connection on my project 'File Valet'."
summary: "Today I have continued my work on File Valet, implementing multi-threading and the SSH connection."
categories: ["File Valet"]
tags: ["rust", "egui", "ssh", "avif", "threading"]
---

Today I properly started with File Valet (you can find more information about it in the last entry).

# Multi-threading

Since egui can only draw the UI if the main thread isnt busy, we have to off-load all network operations to a separete thread. I always like encapsulating those shenanigans into their own struct for ease-of-use.

I am essentially creating a struct that wraps communicating with the secondary thread:
```rs
pub struct FileValet {
    command_tx: mpsc::Sender<FvCommand>,
    event_rx: mpsc::Receiver<FvEvent>,
    ctx_handle: Option<std::thread::JoinHandle<()>>,
    pub state: Arc<FvState>,
}

impl FileValet {
    pub fn new() -> FvResult<Self> {
        let (command_tx, command_rx) = mpsc::channel();
        let (event_tx, event_rx) = mpsc::channel();

        let state = Arc::new(FvState::default());

        let ctx = FvContext {
            command_rx,
            event_tx,
            ssh_session: None,
            state: state.clone(),
        };

        let ctx_handle = std::thread::spawn(move || ctx.run());

        Ok(Self {
            command_tx,
            event_rx,
            ctx_handle: Some(ctx_handle),
            state,
        })
    }

    pub fn poll_event(&self) -> Option<FvEvent> {
        self.event_rx.try_recv().ok()
    }
}
```

While the Context contains the state of whatever runs on the secondary thread:
```rs
pub struct FvContext {
    pub command_rx: mpsc::Receiver<FvCommand>,
    pub event_tx: mpsc::Sender<FvEvent>,
    pub ssh_session: Option<Session>,
    pub state: Arc<FvState>,
}

impl FvContext {
    pub fn run(mut self) {
        while let Ok(command) = self.command_rx.recv() {
            self.handle_command(command);
        }
    }

    fn handle_command(&mut self, command: FvCommand) {
        if let Err(err) = match command {
            FvCommand::Connect { host, port, user } => self.handle_connect(host, port, user),
            FvCommand::Disconnect => {
                self.set_disconnected();
                Ok(())
            }
        } {
            self.send_event(FvEvent::error(err.to_string()))
        }
    }
    
    fn handle_connect(&mut self, host: String, port: u16, user: String) -> FvResult<()> {
        if self.state.is_connecting() {
            return Ok(());
        }
    
        self.set_disconnected();
        self.state.set_connecting(true);
    
        match self.try_connect(host, port, user) {
            Ok(session) => {
                self.set_connected(session);
                Ok(())
            }
            Err(err) => {
                self.state.set_connecting(false);
                Err(err)
            }
        }
    }
    ...
}
```

They got their two-way communication, commands are sent from the main thread and processed by the secondary, while events are sent by the secondary and processed by the main one. They also got some shared state they can both access for small status information.
```rs
#[derive(Debug)]
pub struct FvState {
    connected: AtomicBool,
    connecting: AtomicBool,
}

impl Default for FvState {
    fn default() -> Self {
        Self {
            connected: AtomicBool::new(false),
            connecting: AtomicBool::new(false),
        }
    }
}
```

Overall, I think thats a nice way of handling multi-threaded tasks when dealing with egui. At least thats what I have grown accustomed to.

---

# SSH connection

The connection establishment itself will be pretty primitive for now. You just create a TCP connection, hand it to an `ssh2::Session` and youre (almost) done.
```rs
fn try_connect(&self, host: String, port: u16, user: String) -> FvResult<Session> {
    let tcp = TcpStream::connect((host.as_str(), port))?;
    let mut session = Session::new()?;
    session.set_tcp_stream(tcp);
    session.handshake()?;
    self.authenticate(&session, &user)?;
    Ok(session)
}
```

For authentication I will just support key-auth for now. File Valet will either get that key through the specified user agent (will work if you added a key via `ssh-add` in terminal) or it will naively check common ssh filenames (there is probably a better approach to this, but it works for now).
```rs
fn authenticate(&self, session: &Session, user: &str) -> FvResult<()> {
    if session.userauth_agent(user).is_ok() {
        return Ok(());
    }

    let ssh_dir = dirs::home_dir()
        .ok_or(FvError::NoHomeDirectory)?
        .join(".ssh");

    for name in ["id_ed25519", "id_rsa", "id_ecdsa"] {
        let path = ssh_dir.join(name);
        if path.exists()
            && session
                .userauth_pubkey_file(user, None, &path, None)
                .is_ok()
        {
            return Ok(());
        }
    }

    Err(FvError::NoWorkingAuthenticationMethod)
}
```

This is how it looks in the UI at the moment. It will also show little toasts in the upper right on success or errors (`egui-notify`). Now that we got this we will also be able to talk to my server via SFTP. My dream of an easy workflow of updating pre-processed files to a specific directory on my server with as little friction as possible is coming ever so much closer! >:)

![](https://media.lemon.industries/screenshot-20260514174813.png)

---

# Upload process

For uploading the files to my remote directory I will just use SCP over the SSH connection we already established, with the `ssh2` crate this is relatively trivial. I am sending the data over in 128KB chunks to get a nice upload progress bar.
```rs
fn scp_write(&self, data: &[u8], remote_path: &Path) -> FvResult<()> {
    let session = self.ssh.as_ref().ok_or(FvError::NotConnected)?;
    let mut remote = session.scp_send(remote_path, 0o644, data.len() as u64, None)?;

    for chunk in data.chunks(128 * 1024) {
        remote.write_all(chunk)?;
        self.state.upload.add_bytes_sent(chunk.len() as u64);
    }

    remote.send_eof()?;
    remote.wait_eof()?;
    remote.close()?;
    remote.wait_close()?;
    Ok(())
}
```

To upload multiple different files Im just gonna wrap that SCP-write function and add more state updates.
```rs
fn upload_all(&mut self, files: &[(Vec<u8>, PathBuf)]) -> FvResult<()> {
    for (data, remote_path) in files {
        self.state.upload.set_bytes_total(data.len() as u64);
        self.state.upload.set_bytes_sent(0);

        self.scp_write(data, remote_path)?;

        self.state.upload.add_files_bytes_sent(data.len() as u64);
        self.state.upload.add_files_complete(1);
    }
    
    Ok(())
}
```
You might be wondering why I am using raw vectors instead of file handles. Most of the files Im gonna upload will be pre-processed, which means they will be created completely new from existing files (e.g. to convert PNG to AVIF). I COULD theoretically store the new files in the file system before uploading them to save memory, but I didnt bother doing that yet. Its fine for my usecase for now c:

Just gonna hook it up with my command handler and its all done:
```rs
fn handle_upload(&mut self, files: Vec<(Vec<u8>, PathBuf)>) -> FvResult<()> {
    let upload = &self.state.upload;
    self.state.upload.set_files_total(files.len() as u64);
    self.state
        .upload
        .set_files_bytes_total(files.iter().map(|(d, _)| d.len() as u64).sum());
    upload.set_uploading(true);

    let result = self.upload_all(&files);

    self.state.upload.reset();

    if result.is_ok() {
        self.send_event(FvEvent::UploadComplete);
    }

    result
}
```

Next time I will be able to write a nice UI for this whole upload process and then I am already pretty close to being done.

---

{{< github repo="Zitronenjoghurt/file-valet" showThumbnail=true >}}
