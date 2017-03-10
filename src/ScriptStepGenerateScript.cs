using System.Data.SqlClient;

namespace AlterCollation
{
    /// <summary>
    ///     special script step that will select the results of executing a script and treat
    ///     each selected row as a SQL script
    /// </summary>
    public class ScriptStepGenerateScript : ScriptStep
    {
        public ScriptStepGenerateScript(string resourceIdentifier)
            : base(resourceIdentifier)
        {
        }

        public ScriptStepGenerateScript(ScriptStep basedOn)
            : base(basedOn.CommandText)
        {
        }

        public ScriptStepCollection Script { get; private set; }

        protected override void ExecuteCommand(SqlCommand command)
        {
            Script = new ScriptStepCollection();
            var reader = command.ExecuteReader();
            try
            {
                //this only selects the value in the first column
                while (reader.Read())
                    Script.Add(new ScriptStep(reader.GetString(0)));
            }
            finally
            {
                reader.Close();
            }
        }
    }
}