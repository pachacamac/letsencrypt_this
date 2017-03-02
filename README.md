# letsencrypt_this

simple letsencrypt client

doesn't do much but does it in a relatively simple, convenient and comprehensible way.

In a nutshell it does this:

    > ruby letsencrypt_this.rb -d test.example.com -m test

    test/staging mode
    creating new private key
    Trying to register client ... done.
    creating challenge
    challenge created in: /tmp/letsencrypt_this/test.example.com/.well-known/acme-challenge/MH4d1NeobfW4xEsvmeL1ZT4lwPpbCh5Bi1kxyqU7D1g

    challenge content is:  MH4d1NeobfW4xEsvmeL1ZT4lwPpbCh5Bi1kxyqU7D1g.3t9AgnvylHqhgBKigw1jQt6_unfDzBMZlGigOy8a7b1
    make it accessible at: test.example.com/.well-known/acme-challenge/MH4d1NeobfW4xEsvmeL1ZT4lwPpbCh5Bi1kxyqU7D1g

    checking from local ....................................FOUND!
    attempting letsencrypt challenge verification ...
    waiting for challenge verification ... VERIFIED!
    writing pem files.
    using precomputed dhparam. has nobody got time to wait.
    all done!

    > tree -a test.example.com

    test.example.com
    ├── cert.pem
    ├── chain.pem
    ├── dhparam.pem
    ├── fullchain.pem
    ├── id_rsa
    ├── id_rsa.pub
    ├── letsencrypt_challenge.json
    ├── privkey.pem
    └── .well-known
        └── acme-challenge
            └── MH4d1NeobfW4xEsvmeL1ZT4lwPpbCh5Bi1kxyqU7D1g

    2 directories, 9 files
