window.appConfig = {
    Auth: {
        userPoolId: "eu-west-2_NM1gGgGrq",
        userPoolClientId: "38dmu7mrljf5dqu678ofnf794b",
        region: "eu-west-2",
        oauth: {
            domain: "uktv-event-streaming-app-user-pool-727361020121.auth.eu-west-2.amazoncognito.com",
            scope: ['openid', 'email', 'profile'],
            redirectSignIn: "", // Not used in this flow, but good to have
            redirectSignOut: "", // Not used in this flow
            responseType: 'token'
        }
    },
    ApiEndpoint: "https://9pu1jw5gac.execute-api.eu-west-2.amazonaws.com/Prod",
    AdminApiEndpoint: "https://xaphfzgz94.execute-api.eu-west-2.amazonaws.com/Prod"
};
