window.appConfig = {
    Auth: {
        userPoolId: "eu-west-2_0SgNyOMRl",
        userPoolClientId: "48qqc3sa0godfbinfdpqvqje2j",
        region: "eu-west-2",
        oauth: {
            domain: "uktv-event-streaming-app-user-pool-727361020121.auth.eu-west-2.amazoncognito.com",
            scope: ['openid', 'email', 'profile'],
            redirectSignIn: "", // Not used in this flow, but good to have
            redirectSignOut: "", // Not used in this flow
            responseType: 'token'
        }
    },
    ApiEndpoint: "https://z1mfsic4b7.execute-api.eu-west-2.amazonaws.com/Prod"
};
