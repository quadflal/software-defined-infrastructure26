# Task 30 - Hello server creation

1. Create a Maven based pulumi project
   Solution:

```bash
pulumi new java
```

Result:

```text
pulumi-exercise
├── Pulumi.yaml
├── Pulumi.dev.yaml
├── pom.xml
└── src
    └── main
        └── java
            └── myproject
                └── App.java
```

Content of `App.java`:

```java
public class App {
    public static void main(String[] args) {
        Pulumi.run(ctx -> {
            ctx.export("exampleOutput", Output.of("example"));
        });
    }
}
```

Use following command to set up the HCLOUD_TOKEN environment variable:

```bash
pulumi config set --secret hcloud:token YOUR_HCLOUD_API_TOKEN
```