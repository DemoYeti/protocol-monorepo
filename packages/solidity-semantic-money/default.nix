{
  halfBoardModule = {
    dependencies = [ ../.. ];
    outputs = [
      "node_modules"
      "out"
    ];
    includedFiles = [
      ./package.json
      ./foundry.toml
      ./src
      ./test
    ];
  };
}
