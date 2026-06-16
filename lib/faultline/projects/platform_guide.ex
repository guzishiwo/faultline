defmodule Faultline.Projects.PlatformGuide do
  @moduledoc """
  SDK setup snippets for project onboarding.
  """

  alias Faultline.Projects.Project

  def build(%Project{} = project) do
    platform = project.platform || Project.default_platform()
    label = Project.platform_label(platform)

    platform
    |> recipe(project.dsn)
    |> Map.merge(%{
      platform_id: platform,
      platform_label: label,
      docs_url: docs_url(platform)
    })
  end

  defp recipe("other", dsn) do
    %{
      install: [],
      configure_title: "Save your DSN",
      configure_language: "text",
      configure_code: "DSN=#{dsn}",
      verify_language: "text",
      verify_code:
        "Choose a concrete platform when you know where this project will send events from.",
      note: "Use this project now, then switch to a specific SDK guide when the runtime is known."
    }
  end

  defp recipe("nextjs", dsn),
    do: javascript_recipe("@sentry/nextjs", "@sentry/nextjs", dsn, "sentry.client.config.js")

  defp recipe("react", dsn), do: javascript_recipe("@sentry/react", "@sentry/react", dsn)

  defp recipe("react_native", dsn),
    do: javascript_recipe("@sentry/react-native", "@sentry/react-native", dsn)

  defp recipe("nodejs", dsn),
    do: javascript_recipe("@sentry/node", "@sentry/node", dsn, "instrument.js")

  defp recipe("express", dsn),
    do: javascript_recipe("@sentry/node", "@sentry/node", dsn, "instrument.js")

  defp recipe("nestjs", dsn),
    do: javascript_recipe("@sentry/node", "@sentry/node", dsn, "instrument.ts")

  defp recipe("browser_javascript", dsn),
    do: javascript_recipe("@sentry/browser", "@sentry/browser", dsn)

  defp recipe("vue", dsn), do: javascript_recipe("@sentry/vue", "@sentry/vue", dsn)
  defp recipe("angular", dsn), do: javascript_recipe("@sentry/angular", "@sentry/angular", dsn)

  defp recipe("nuxt", dsn),
    do: javascript_recipe("@sentry/nuxt", "@sentry/nuxt", dsn, "plugins/sentry.client.ts")

  defp recipe("remix", dsn), do: javascript_recipe("@sentry/remix", "@sentry/remix", dsn)

  defp recipe("electron", dsn),
    do: javascript_recipe("@sentry/electron", "@sentry/electron/main", dsn, "main.js")

  defp recipe("cloudflare_workers", dsn),
    do: javascript_recipe("@sentry/cloudflare", "@sentry/cloudflare", dsn, "src/index.ts")

  defp recipe("python", dsn), do: python_recipe("sentry-sdk", dsn, nil)
  defp recipe("fastapi", dsn), do: python_recipe("sentry-sdk[fastapi]", dsn, "FastApiIntegration")
  defp recipe("django", dsn), do: python_recipe("sentry-sdk[django]", dsn, "DjangoIntegration")
  defp recipe("flask", dsn), do: python_recipe("sentry-sdk[flask]", dsn, "FlaskIntegration")

  defp recipe("rails", dsn) do
    %{
      install: [
        %{label: "bundle", command: "bundle add sentry-ruby sentry-rails"}
      ],
      configure_title: "config/initializers/sentry.rb",
      configure_language: "ruby",
      configure_code: """
      Sentry.init do |config|
        config.dsn = "#{dsn}"
        config.breadcrumbs_logger = [:active_support_logger, :http_logger]
      end
      """,
      verify_language: "ruby",
      verify_code: "Sentry.capture_message(\"Faultline SDK configured\")",
      note: "Restart Rails after adding the initializer."
    }
  end

  defp recipe("php", dsn),
    do: php_recipe("composer require sentry/sdk", dsn, "Sentry\\init(['dsn' => '#{dsn}']);")

  defp recipe("laravel", dsn),
    do: php_recipe("composer require sentry/sentry-laravel", dsn, "SENTRY_LARAVEL_DSN=#{dsn}")

  defp recipe("symfony", dsn),
    do: php_recipe("composer require sentry/sentry-symfony", dsn, "SENTRY_DSN=#{dsn}")

  defp recipe("ios", dsn) do
    %{
      install: [
        %{label: "Swift Package", command: "https://github.com/getsentry/sentry-cocoa"}
      ],
      configure_title: "AppDelegate.swift",
      configure_language: "swift",
      configure_code: """
      import Sentry

      SentrySDK.start { options in
        options.dsn = "#{dsn}"
      }
      """,
      verify_language: "swift",
      verify_code: "SentrySDK.capture(message: \"Faultline SDK configured\")",
      note: "Add Sentry as a Swift Package dependency, then initialize it as early as possible."
    }
  end

  defp recipe("android", dsn) do
    %{
      install: [
        %{label: "Gradle", command: "implementation \"io.sentry:sentry-android:latest.release\""}
      ],
      configure_title: "AndroidManifest.xml",
      configure_language: "markup",
      configure_code: """
      <meta-data android:name="io.sentry.dsn" android:value="#{dsn}" />
      """,
      verify_language: "kotlin",
      verify_code: "Sentry.captureMessage(\"Faultline SDK configured\")",
      note: "Place the metadata inside your application manifest."
    }
  end

  defp recipe("flutter", dsn) do
    %{
      install: [
        %{label: "flutter", command: "flutter pub add sentry_flutter"}
      ],
      configure_title: "main.dart",
      configure_language: "dart",
      configure_code: """
      import 'package:sentry_flutter/sentry_flutter.dart';

      Future<void> main() async {
        await SentryFlutter.init(
          (options) {
            options.dsn = '#{dsn}';
          },
          appRunner: () => runApp(const MyApp()),
        );
      }
      """,
      verify_language: "dart",
      verify_code: "Sentry.captureMessage('Faultline SDK configured');",
      note: "Wrap app startup so Sentry is initialized before the first frame."
    }
  end

  defp recipe("aspnet_core", dsn),
    do:
      dotnet_recipe(
        "dotnet add package Sentry.AspNetCore",
        dsn,
        "builder.WebHost.UseSentry(\"#{dsn}\");"
      )

  defp recipe("dotnet_maui", dsn),
    do:
      dotnet_recipe(
        "dotnet add package Sentry.Maui",
        dsn,
        "builder.UseSentry(options => options.Dsn = \"#{dsn}\");"
      )

  defp recipe("spring_boot", dsn),
    do: java_recipe("io.sentry:sentry-spring-boot-starter-jakarta", dsn)

  defp recipe("unity", dsn), do: unity_recipe(dsn)
  defp recipe(_platform, dsn), do: recipe("other", dsn)

  defp javascript_recipe(package, import_path, dsn, filename \\ "main.js") do
    %{
      install: [
        %{label: "npm", command: "npm install --save #{package}"},
        %{label: "yarn", command: "yarn add #{package}"},
        %{label: "pnpm", command: "pnpm add #{package}"}
      ],
      configure_title: filename,
      configure_language: "javascript",
      configure_code: """
      import * as Sentry from "#{import_path}";

      Sentry.init({
        dsn: "#{dsn}"
      });
      """,
      verify_language: "javascript",
      verify_code: "Sentry.captureMessage(\"Faultline SDK configured\");",
      note: "Initialize the SDK as early as possible in your application lifecycle."
    }
  end

  defp python_recipe(package, dsn, nil) do
    %{
      install: [
        %{label: "pip", command: "pip install \"#{package}\""},
        %{label: "uv", command: "uv add \"#{package}\""}
      ],
      configure_title: "app startup",
      configure_language: "python",
      configure_code: """
      import sentry_sdk

      sentry_sdk.init(
          dsn="#{dsn}",
      )
      """,
      verify_language: "python",
      verify_code: "sentry_sdk.capture_message(\"Faultline SDK configured\")",
      note: "Run this during application startup before handling requests."
    }
  end

  defp python_recipe(package, dsn, integration) do
    %{
      install: [
        %{label: "pip", command: "pip install \"#{package}\""},
        %{label: "uv", command: "uv add \"#{package}\""}
      ],
      configure_title: "app startup",
      configure_language: "python",
      configure_code: """
      import sentry_sdk
      from sentry_sdk.integrations.#{python_integration_module(integration)} import #{integration}

      sentry_sdk.init(
          dsn="#{dsn}",
          integrations=[#{integration}()],
      )
      """,
      verify_language: "python",
      verify_code: "sentry_sdk.capture_message(\"Faultline SDK configured\")",
      note: "Initialize Sentry before your framework starts serving requests."
    }
  end

  defp php_recipe(command, _dsn, configure_code) do
    %{
      install: [
        %{label: "composer", command: command}
      ],
      configure_title: ".env or bootstrap",
      configure_language: "php",
      configure_code: configure_code,
      verify_language: "php",
      verify_code: "\\Sentry\\captureMessage('Faultline SDK configured');",
      note: "For framework packages, publish/configure the bundle after installation."
    }
  end

  defp dotnet_recipe(command, _dsn, configure_code) do
    %{
      install: [
        %{label: ".NET CLI", command: command}
      ],
      configure_title: "Program.cs",
      configure_language: "csharp",
      configure_code: configure_code,
      verify_language: "csharp",
      verify_code: "SentrySdk.CaptureMessage(\"Faultline SDK configured\");",
      note: "Initialize Sentry during host builder setup."
    }
  end

  defp java_recipe(package, dsn) do
    %{
      install: [
        %{label: "Gradle", command: "implementation \"#{package}:latest.release\""},
        %{label: "Maven", command: "<artifactId>sentry-spring-boot-starter-jakarta</artifactId>"}
      ],
      configure_title: "application.properties",
      configure_language: "properties",
      configure_code: "sentry.dsn=#{dsn}",
      verify_language: "java",
      verify_code: "Sentry.captureMessage(\"Faultline SDK configured\");",
      note: "Add the property before starting the Spring Boot application."
    }
  end

  defp unity_recipe(dsn) do
    %{
      install: [
        %{label: "Unity Package", command: "https://github.com/getsentry/unity.git"}
      ],
      configure_title: "Sentry options",
      configure_language: "csharp",
      configure_code: """
      SentrySdk.Init(options =>
      {
          options.Dsn = "#{dsn}";
      });
      """,
      verify_language: "csharp",
      verify_code: "SentrySdk.CaptureMessage(\"Faultline SDK configured\");",
      note: "Add the Unity SDK package and set the DSN in project startup."
    }
  end

  defp python_integration_module("DjangoIntegration"), do: "django"
  defp python_integration_module("FlaskIntegration"), do: "flask"
  defp python_integration_module("FastApiIntegration"), do: "fastapi"

  defp docs_url("other"), do: nil
  defp docs_url("browser_javascript"), do: "https://docs.sentry.io/platforms/javascript/"
  defp docs_url("react"), do: "https://docs.sentry.io/platforms/javascript/guides/react/"
  defp docs_url("nextjs"), do: "https://docs.sentry.io/platforms/javascript/guides/nextjs/"
  defp docs_url("react_native"), do: "https://docs.sentry.io/platforms/react-native/"
  defp docs_url("nodejs"), do: "https://docs.sentry.io/platforms/javascript/guides/node/"
  defp docs_url("express"), do: "https://docs.sentry.io/platforms/javascript/guides/express/"
  defp docs_url("nestjs"), do: "https://docs.sentry.io/platforms/javascript/guides/nestjs/"

  defp docs_url("cloudflare_workers"),
    do: "https://docs.sentry.io/platforms/javascript/guides/cloudflare/"

  defp docs_url("electron"), do: "https://docs.sentry.io/platforms/javascript/guides/electron/"
  defp docs_url("python"), do: "https://docs.sentry.io/platforms/python/"
  defp docs_url("fastapi"), do: "https://docs.sentry.io/platforms/python/integrations/fastapi/"
  defp docs_url("django"), do: "https://docs.sentry.io/platforms/python/integrations/django/"
  defp docs_url("flask"), do: "https://docs.sentry.io/platforms/python/integrations/flask/"
  defp docs_url("dotnet_maui"), do: "https://docs.sentry.io/platforms/dotnet/guides/maui/"
  defp docs_url("aspnet_core"), do: "https://docs.sentry.io/platforms/dotnet/guides/aspnetcore/"
  defp docs_url(platform), do: "https://docs.sentry.io/platforms/#{platform}/"
end
