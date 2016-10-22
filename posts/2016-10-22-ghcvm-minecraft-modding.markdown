---
title: Lets make Minecraft mod on Haskell
image: images/minecraft_logo_dirt.png
description: GHCVM (JVM backend for GHC) is now ready to be used for Minecraft moding. The post will tell you how to setup minimum development environment for Haskell based mod.
---

## <a name="prerequisites">Prerequisites</a>

I expect that you run a GNU/Linux system, but other systems experience shouldn't
differ a lot. If you run into any problems, you can post them in:

* comments for the post for tutorial specific questions.

* [ghcvm](https://github.com/rahulmutt/ghcvm/tree/master) issue tracker
or [chat](https://gitter.im/rahulmutt/ghcvm) for issues with GHCVM implementation.

## <a name="ghcvm_installation">GHCVM installation</a>

Follow the official [GHCVM guide](https://github.com/rahulmutt/ghcvm#method-1-normal-installation). You should end up with `ghcvm` and `cabalvm` executables on your PATH environment variable.

## <a name="forge_installation">Forge environment setup</a>

Now we need a minimal Minecraft Forge developer environment. Go to the [official site](http://files.minecraftforge.net/) of Forge and download the latest `Mdk` archive.

Extract it anywhere:

``` bash
unzip forge-1.10.2-12.18.2.2099-mdk.zip -d forge
```

Create a new folder for your personal mod, lets call it `hello`, and copy the
following files from unpacked forge archive:

* `build.gradle` - defines how to build and run your mod with [gradle](https://gradle.org/) Java tool.

* `gradle` folder with [gradle](https://gradle.org/) tool itself.

* `gradlew` and `gradlew.bat` scripts for running the local [gradle](https://gradle.org/).

* `src` - folder with Java sources of your mod.

Also you can copy `eclipse` folder if you desire to use the IDE and copy license
files to respect legal issues.

Finally, lets bootstrap it:

``` bash
./gradlew setupDecompWorkspace
./gradlew runClient
```

After the last command a MC client should start with Forge and dummy mod.

## <a name="haskell_part">Adding Haskell part</a>

We are comming to part where the tutorial differs from common way to mod MC. Lets
init Haskell subproject:

``` bash
cd src/main
mkdir haskell
cd haskell
cabalvm init
```

Next answer some simple questions about *"what's your name?"*, *"what's your purpose?"*.
You can answer whatever you like, but for some of them the tutorial expects the following answers:

``` bash
Package name? [default: main] hello
....
What does the package build:
   1) Library
   2) Executable
Your choice? 2
....
Source directory:
 * 1) (none)
   2) src
   3) Other (specify)
Your choice? [default: (none)] 2
```

The executable option is important as `cabalvm` will collect all dependencies alongside
with your app and pack them in one mega jar. That can save you a bundle of nerves
in near future. Although we are not going to use `main` method of the executable at all.

Now we create the `Main` module of mentioned dummy executable. Put the following
in new file `src/Main.hs`:

``` haskell
module Main where

main :: IO ()
main = return ()
```

Now we need a module for global Java exports, put the following into `src/Export.hs`:
``` haskell
{-# LANGUAGE MagicHash #-}
module Export where

import GHC.Base
import GHC.Pack

-- | Our first mod will greet a player on chat command
--
-- `Java class a` is special monad that works in context of class `class` and
-- returns type `a`.
sayHello :: JString -> Java Export JString
sayHello n = return . mkJString $ "Hello, " ++ unpackCString n ++ "!"

-- The following line tells GHCVM to create Java class `Export`
-- at package `hello`. We will use it as some sort of interface to Haskell world.
data {-# CLASS "hello.Export" #-} Export = Export (Object# Export)

-- Generate export wrapper that evaulates Haskell thunks
foreign export java sayHello :: JString -> Java Export JString
```

And add `Export` module to `other-modules` in `hello.cabal`:
``` haskell
-- ...

executable hello
  main-is:             Main.hs
  other-modules:       Export

-- ...
```

Check that `cabalvm` can build Haskell jar:
``` bash
$ cabalvm build
Package has never been configured. Configuring with default flags. If this
fails, please run configure manually.
Warning: The package list for 'hackage.haskell.org' does not exist. Run 'cabal
update' to download it.
Resolving dependencies...
Configuring hello-0.1.0.0...
Building hello-0.1.0.0...
Preprocessing executable 'hello' for hello-0.1.0.0...
[1 of 2] Compiling Main             ( src/Main.hs, dist/build/hello/hello-tmp/Main.jar )
[2 of 2] Compiling Export           ( src/Export.hs, dist/build/hello/hello-tmp/Export.jar )
Linking dist/build/hello/hello.jar ...
```

### <a name="haskell_dependency">Add Haskell dependency</a>

So far we have a compiled Haskell jar file located at `src/main/haskell/dist/build/hello/hello.jar` and it would be nice to link it to our Minecraft application.

First, find `dependencies` section
and add line as follows:
``` json
dependencies {
    compile fileTree(dir: 'libs', include: ['*.jar'])

    // here is a huge comment block
}
```

Gradle will add all `libs/*.jar` to our `.classpath` at build and start. Next,
add Haskell rebuild task to the end of `build.gradle`:
``` json
task compileHaskell(type:Exec) {
    workingDir "src/main/haskell"
    commandLine "cabalvm", "build"
}

task copyHaskellJar(type: Copy) {
    dependsOn compileHaskell
    from 'src/main/haskell/dist/build/hello/hello.jar'
    into 'libs'
}

tasks.build.dependsOn(copyHaskellJar)
```

Now you can manually call:
``` bash
./gradlew copyHaskellJar
```

Or simply run:
``` bash
./gradlew build
```

And your Haskell part will be recompiled and copied in dependency folder automatically!

### <a name="call_haskell">Call Haskell from Java</a>

The last step is left, we need to call our gorgeous `sayHello` function in response
to chat command `\hello <name>`.

First, we need to initialise our `hello.Export` class and place at some global
scope. Edit `src/main/java/com/example/examplemod/ExampleMod.java`:
``` Java
package com.example.examplemod;

import ghcvm.runtime.*;
import hello.Export;
import net.minecraft.init.Blocks;
import net.minecraftforge.fml.common.event.FMLInitializationEvent;
import net.minecraftforge.fml.common.event.FMLServerStartingEvent;
import net.minecraftforge.fml.common.Mod.EventHandler;
import net.minecraftforge.fml.common.Mod;

@Mod(modid = ExampleMod.MODID, version = ExampleMod.VERSION)
public class ExampleMod
{
    public static final String MODID = "examplemod";
    public static final String VERSION = "1.0";
    public static Export HASKELL;

    @EventHandler
    public void init(FMLInitializationEvent event)
    {
        // We need to init Haskell RTS once
        Rts.hsInit(new String[0], RtsConfig.getDefault());
        // Create our class with exported Haskell functions
        HASKELL = new Export();
    }

    @EventHandler
    public void serverLoad(FMLServerStartingEvent event) {
        event.registerServerCommand(new CommandHello());
    }
}
```

Finally, create new `CommandHello.java` class at `src/main/java/com/example/examplemod` folder:
``` Java
package com.example.examplemod;

import java.util.ArrayList;
import java.util.List;
import javax.annotation.Nullable;
import net.minecraft.command.CommandException;
import net.minecraft.command.ICommand;
import net.minecraft.command.ICommandSender;
import net.minecraft.server.MinecraftServer;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.text.TextComponentString;
import net.minecraft.world.World;

public class CommandHello implements ICommand {
    private final List aliases;

    public CommandHello() {
        aliases = new ArrayList();
        aliases.add("hello");
    }

    @Override
    public String getCommandName() {
        return "hello";
    }

    @Override
    public String getCommandUsage(ICommandSender sender) {
        return "hello name";
    }

    @Override
    public List<String> getCommandAliases() {
        return this.aliases;
    }

    @Override
    public void execute(MinecraftServer server, ICommandSender sender, String[] args)
        throws CommandException
    {
        World world = sender.getEntityWorld();

        if (!world.isRemote) {
            String v = ExampleMod.HASKELL.sayHello("NCrashed");
            sender.addChatMessage(new TextComponentString(v));
        }
    }

    @Override
    public boolean checkPermission(MinecraftServer server, ICommandSender sender) {
        return true;
    }

    @Override
    public List<String> getTabCompletionOptions(MinecraftServer server
        , ICommandSender sender
        , String[] args
        , @Nullable BlockPos pos)
    {
        return new ArrayList();
    }

    @Override
    public boolean isUsernameIndex(String[] args, int index) {
        return false;
    }

    @Override
    public int compareTo(ICommand iCommand) {
        return 0;
    }
}

```

Thats all, run `./gradlew runClient` and you now able to say "Hello" form Haskell!

![](/images/minecraft_hello_ghcvm_screenshot.png#center-sized)


## <a name="intellij">Setup IntelliJ IDEA</a>

You can develop with [IntelliJ IDEA](https://www.jetbrains.com/idea/). Import the
local `build.gradle` as gradle project at IDEA startup screen.

![](/images/minecraft_hello_ghcvm_idea.png#center-sized)

And generate run targets for it:
``` bash
./gradlew genIntellijRuns
```

Also you can run into the following problem while trying to run the mod from IDEA:
``` bash
Exception in thread "main" java.lang.ClassNotFoundException: GradleStart
  at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
  at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
  at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
  at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
  at java.lang.Class.forName0(Native Method)
  at java.lang.Class.forName(Class.java:264)
```

You need to change classpath module to `hello_main` in run configuration edit
dialog:
![](/images/minecraft_hello_ghcvm_idea_run.png#center-sized)

## <a name="references">References</a>

* Assembled project [repo](https://github.com/NCrashed/minecraft-ghcvm-helloworld)