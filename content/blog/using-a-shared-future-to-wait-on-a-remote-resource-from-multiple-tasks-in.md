---
date: 2020-07-21
title: Using a shared future to wait on a remote resource from multiple tasks in Rust
slug: using-a-shared-future-to-wait-on-a-remote-resource-from-multiple-tasks-in
categories: [Backend]
tags: [rust]
---

This example shows how to wait on a single future from multiple tasks at the same time using [Shared future](https://docs.rs/futures/0.3.5/futures/future/struct.Shared.html).

In this example, a client makes multiple concurrent requests to a server. The server then makes a single request to a remote resource on behalf of the client and resolves each of the client's requests with the single value returned from the remote resource. 

Check out the code here: [https://github.com/danbruder/shared-future-example](https://github.com/danbruder/shared-future-example)

```rust
use std::collections::HashMap;
use std::marker::Send;
use std::pin::Pin;

use futures::future::{join_all, Shared};
use futures::prelude::*;
use futures::Future;
use once_cell::sync::OnceCell;
use tokio::{
    sync::Mutex,
    time::{delay_for, Duration},
};
use uuid::Uuid;

/// SpecialData
/// Represents some data returned from a remote system
#[derive(Debug, Clone)]
struct SpecialData {
    pub key: String,
    pub data: Uuid,
}

/// Request Registry
/// This global mutex holds on to in-flight futures (requests) to the remote system
fn request_registry(
) -> &'static Mutex<HashMap<String, Shared<Pin<Box<dyn Future<Output = SpecialData> + Send>>>>> {
    static INSTANCE: OnceCell<
        Mutex<HashMap<String, Shared<Pin<Box<dyn Future<Output = SpecialData> + Send>>>>>,
    > = OnceCell::new();
    INSTANCE.get_or_init(|| {
        let registry = HashMap::new();
        Mutex::new(registry)
    })
}

/// Request spy
/// Used just for this example to log requests to the remote system, showing that only
/// one request per client is in flight at a time
fn request_spy() -> &'static Mutex<Vec<String>> {
    static INSTANCE: OnceCell<Mutex<Vec<String>>> = OnceCell::new();
    INSTANCE.get_or_init(|| {
        let spy = Vec::new();
        Mutex::new(spy)
    })
}

/// Make Request to Remote System
/// This is a dummy function simulating a call to a remote system
/// to fetch the special data
async fn make_request_to_remote_system(key: String) -> SpecialData {
    let data = Uuid::new_v4();

    // Artificial delay simulating a network request
    delay_for(Duration::from_secs(2)).await;

    // Log the request for this example to show it is only called once per client
    request_spy()
        .lock()
        .await
        .push(format!("Request from client {}, returning {}", key, data));

    SpecialData { key, data }
}

/// Get Special Data
/// This function abstracts the request to the remote system
/// making sure there's only one in flight request per key at a time
async fn get_special_data(key: &str) -> SpecialData {
    // Get a lock on the request registry
    let mut requests = request_registry().lock().await;
    // Check to see if there is already a request for that key
    let maybe_in_flight_request = requests.get(key).map(|inner| inner.clone());

    // If there is, use the future associated with that request
    let fut = if maybe_in_flight_request.is_some() {
        maybe_in_flight_request.unwrap()
    } else {
        // If not, create a new request. The call to shared() creates a
        // shared future that can be cloned and awaited by other tasks
        let request = make_request_to_remote_system(key.to_owned())
            .boxed()
            .shared();

        // Store the created future so others can await on it
        requests.insert(key.into(), request.clone());

        request
    };

    // Release the lock on the request registry so other requests can
    // register to wait on a remote resource
    drop(requests);

    // await the future - it will now start fetching the remote data
    let result = fut.await;

    // When the future resolves, get a lock on the registry again
    let mut requests = request_registry().lock().await;
    // Remove the request from the registry
    requests.remove(key);

    result

    // `requests` goes out of scope, releasing the lock on the registry
}

#[tokio::main]
async fn main() {
    // key1 and key2 represent two clients making requests to the system
    // at the same time. They each make multiple concurrent requests
    let key1 = "Some key";
    let key2 = "Some other key";

    let all = join_all(vec![
        get_special_data(key1),
        get_special_data(key1),
        get_special_data(key2),
        get_special_data(key2),
        get_special_data(key1),
        get_special_data(key2),
        get_special_data(key2),
        get_special_data(key2),
    ])
    .await;

    assert_each_key_has_same_data_from_remote_system(&all);

    let spy = request_spy().lock().await;

    dbg!(&all);
    dbg!(&spy);

    // Prints ->
    //
    //     [src/main.rs:129] &all = [
    //     SpecialData {
    //         key: "Some key",
    //         data: 24223005-2f8a-44be-b77b-6520f6b04949,
    //     },
    //     SpecialData {
    //         key: "Some key",
    //         data: 24223005-2f8a-44be-b77b-6520f6b04949,
    //     },
    //     SpecialData {
    //         key: "Some other key",
    //         data: 1aadc103-e3ea-42cc-90c6-b77da51b3ccc,
    //     },
    //     SpecialData {
    //         key: "Some other key",
    //         data: 1aadc103-e3ea-42cc-90c6-b77da51b3ccc,
    //     },
    //     SpecialData {
    //         key: "Some key",
    //         data: 24223005-2f8a-44be-b77b-6520f6b04949,
    //     },
    //     SpecialData {
    //         key: "Some other key",
    //         data: 1aadc103-e3ea-42cc-90c6-b77da51b3ccc,
    //     },
    //     SpecialData {
    //         key: "Some other key",
    //         data: 1aadc103-e3ea-42cc-90c6-b77da51b3ccc,
    //     },
    //     SpecialData {
    //         key: "Some other key",
    //         data: 1aadc103-e3ea-42cc-90c6-b77da51b3ccc,
    //     },
    // ]
    // [src/main.rs:130] &spy = [
    //     "Request from client Some key, returning 24223005-2f8a-44be-b77b-6520f6b04949",
    //     "Request from client Some other key, returning 1aadc103-e3ea-42cc-90c6-b77da51b3ccc",
    // ]
}

fn assert_each_key_has_same_data_from_remote_system(items: &[SpecialData]) {
    // Collect data returned from remote system by key
    let mut m = HashMap::new();
    for item in items {
        m.entry(&item.key).or_insert_with(Vec::new).push(item.data)
    }

    // For each key, check to see that all remote data values are the same
    for (_, values) in m {
        let got = values.windows(2).all(|w| w[0] == w[1]);
        let want = true;
        assert_eq!(got, want);
    }
}
```
