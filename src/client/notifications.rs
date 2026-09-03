use std::io;

use tracing::{debug, info, warn};

use crate::protocol::NotifyKind;

use super::shell;

pub(super) fn handle_shell_notification_effects(
    effects: Vec<shell::ClientShellNotificationEffect>,
    sound_config: &crate::config::SoundConfig,
    event_tx: &tokio::sync::mpsc::Sender<super::ClientLoopEvent>,
) {
    for effect in effects {
        match effect {
            shell::ClientShellNotificationEffect::Sound { sound, agent } => {
                let agent = agent.as_deref().and_then(crate::detect::parse_agent_label);
                if sound_config.allows(agent) {
                    crate::sound::play(sound, sound_config);
                }
            }
            shell::ClientShellNotificationEffect::Terminal { title, body } => {
                if let Err(err) = crate::terminal_notify::show_notification(&title, body.as_deref())
                {
                    warn!(err = %err, "failed to emit terminal notification");
                }
            }
            shell::ClientShellNotificationEffect::System {
                title,
                body,
                pane_id,
            } => {
                handle_system_notification(&title, body.as_deref(), pane_id, event_tx.clone());
            }
        }
    }
}

fn handle_system_notification(
    title: &str,
    body: Option<&str>,
    pane_id: Option<String>,
    event_tx: tokio::sync::mpsc::Sender<super::ClientLoopEvent>,
) {
    #[cfg(target_os = "linux")]
    if let Some(pane_id) = pane_id {
        let result =
            crate::platform::show_desktop_notification_with_open_action(title, body, move || {
                info!(pane_id, "desktop notification open action activated");
                let _ = event_tx.blocking_send(super::ClientLoopEvent::NotificationOpen(pane_id));
                match crate::platform::focus_sway_wezterm_window() {
                    Ok(true) => debug!("focused Sway WezTerm window from desktop notification"),
                    Ok(false) => warn!("Sway WezTerm focus prerequisites were not available"),
                    Err(err) => warn!(err = %err, "failed to focus Sway WezTerm window"),
                }
            });
        if let Err(err) = result {
            warn!(err = %err, "failed to emit actionable system notification");
        }
        return;
    }

    let _ = (pane_id, event_tx);
    if let Err(err) = crate::platform::show_desktop_notification(title, body) {
        warn!(err = %err, "failed to emit system notification");
    }
}

pub(super) fn handle_notify(
    kind: NotifyKind,
    message: &str,
    body: Option<&str>,
    sound_config: &crate::config::SoundConfig,
) {
    handle_notify_with_notifiers(
        kind,
        message,
        body,
        sound_config,
        crate::terminal_notify::show_notification,
        crate::platform::show_desktop_notification,
    );
}

pub(super) fn handle_notify_with_notifiers(
    kind: NotifyKind,
    message: &str,
    body: Option<&str>,
    sound_config: &crate::config::SoundConfig,
    mut show_terminal_notification: impl FnMut(&str, Option<&str>) -> io::Result<bool>,
    mut show_system_notification: impl FnMut(&str, Option<&str>) -> io::Result<bool>,
) {
    match kind {
        NotifyKind::Sound => {
            let Some(sound) = sound_from_notify_message(message) else {
                warn!(
                    message = message,
                    "received unknown sound notification from server"
                );
                return;
            };
            if sound_config.enabled {
                crate::sound::play(sound, sound_config);
            }
        }
        NotifyKind::Toast => {
            debug!(
                message = message,
                "received terminal toast notification from server"
            );
            if let Err(err) = show_terminal_notification(message, body) {
                warn!(err = %err, "failed to emit terminal notification");
            }
        }
        NotifyKind::SystemToast => {
            debug!(
                message = message,
                "received system toast notification from server"
            );
            if let Err(err) = show_system_notification(message, body) {
                warn!(err = %err, "failed to emit system notification");
            }
        }
    }
}

pub(super) fn sound_from_notify_message(message: &str) -> Option<crate::sound::Sound> {
    match message {
        "agent done" => Some(crate::sound::Sound::Done),
        "agent attention" => Some(crate::sound::Sound::Request),
        _ => None,
    }
}
