namespace src.Tests;

[Trait("Category", "Unit")]
public class UnitTest1
{
    [Fact]
    public void Test1()
    {
        // Arrange
        var x = 1;
        var y = 2;
        var expected = 3;

        // Act
        var actual = x + y;

        // Assert
        actual.Should().Be(expected);
    }
}