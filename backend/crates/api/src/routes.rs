use axum::{routing::{get, post, put, delete}, Router};
use crate::state::AppState;

pub fn create_routes(state: AppState) -> Router {
    Router::new()
        .route("/config/map", get(user::handlers::get_map_config))
        .route("/avatars/{user_id}", get(user::handlers::get_avatar))
        .nest("/auth", auth_routes())
        .nest("/users", user_routes())
        .nest("/groups", group_routes())
        .nest("/sharing", sharing_routes())
        .nest("/location", location_routes())
        .nest("/trajectory", trajectory_routes())
        .nest("/notifications", notification_routes())
        .nest("/admin", admin_routes())
        .with_state(state)
}

fn auth_routes() -> Router<AppState> {
    Router::new()
        .route("/register", post(auth::handlers::register))
        .route("/login", post(auth::handlers::login))
        .route("/refresh", post(auth::handlers::refresh_token))
}

fn user_routes() -> Router<AppState> {
    Router::new()
        .route(
            "/profile",
            get(user::handlers::get_profile).put(user::handlers::update_profile),
        )
        .route("/profile/avatar", post(user::handlers::upload_avatar))
}

fn group_routes() -> Router<AppState> {
    Router::new()
        .route("/", post(user::handlers::create_group).get(user::handlers::list_groups))
        .route(
            "/invitations",
            get(user::handlers::list_family_invitations),
        )
        .route(
            "/invitations/{invitation_id}",
            put(user::handlers::respond_family_invitation),
        )
        .route("/{id}", delete(user::handlers::delete_group))
        .route("/{id}/members", post(user::handlers::invite_member))
        .route(
            "/{id}/members/{member_id}",
            delete(user::handlers::remove_member),
        )
}

fn sharing_routes() -> Router<AppState> {
    Router::new()
        .route("/", post(user::handlers::request_sharing).get(user::handlers::list_sharing))
        .route("/peer/{viewer_id}", put(user::handlers::put_sharing_peer))
        .route("/{id}", put(user::handlers::update_sharing).delete(user::handlers::delete_sharing))
        .route("/{id}/respond", put(user::handlers::respond_sharing))
}

fn location_routes() -> Router<AppState> {
    Router::new()
        .route("/upload", post(location::handlers::upload))
        .route("/latest", get(location::handlers::get_latest))
        .route("/shared/{user_id}", get(location::handlers::get_shared))
        .route("/family/{group_id}", get(location::handlers::get_family))
}

fn trajectory_routes() -> Router<AppState> {
    Router::new()
        .route("/day-summary", get(trajectory::handlers::query_day_summary))
        .route("/optimized", get(trajectory::handlers::query_optimized_trajectory))
        .route("/", get(trajectory::handlers::query_trajectory))
}

fn notification_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(notification::handlers::list_notifications))
        .route("/{id}/read", put(notification::handlers::mark_read))
        .route("/read-all", put(notification::handlers::mark_all_read))
}

fn admin_routes() -> Router<AppState> {
    Router::new()
        .route("/login", post(admin::handlers::login))
        .route("/users", get(admin::handlers::list_users))
        .route("/stats", get(admin::handlers::get_stats))
        .route("/configs", get(admin::handlers::list_configs))
        .route("/configs/{key}", put(admin::handlers::update_config))
}
