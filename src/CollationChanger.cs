using System;
using System.Collections;
using System.Data.SqlClient;
using System.Globalization;
using System.Reflection;

namespace ChangeCollation
{
    public class CollationChanger
    {
        private bool Canceled { get; set; }

        public ScriptStepCollection GenerateScript(IScriptExecuteCallback callback,
            string server,
            string userId,
            string password,
            string database,
            bool dropAllConstraints,
            string collation,
            FullTextLanguage language,
            bool setSingleUser,
            bool auditOnly)
        {
            SqlConnection connection = new SqlConnection {
                ConnectionString = Utils.ConnectionString(server, userId, password)
            };

            try
            {
                connection.Open();
                ScriptStepCollection script = LoadScript(new Version(connection.ServerVersion),
                    database,
                    dropAllConstraints,
                    collation,
                    language,
                    setSingleUser,
                    auditOnly);
                //now get the last script entry and replace it with 
                //a special component that will return out

                ScriptStepGenerateScript generator = new ScriptStepGenerateScript(script[script.Count - 1]);
                script[script.Count - 1] = generator;
                script.Execute(connection, callback);
                return generator.Script;
            }
            finally
            {
                connection.Dispose();
            }
        }

        public void Cancel()
        {
            Canceled = true;
        }

        ///look in the assembly manifest resources for the script files
        ///get the ones that are SQL scripts and order them
        private ScriptStepCollection LoadScript(Version serverVersion,
            string database,
            bool dropAllConstraints,
            string collation,
            FullTextLanguage language,
            bool setSingleUser,
            bool auditOnly)
        {
            ScriptStepCollection script = new ScriptStepCollection();
            Assembly thisAssembly = GetType().Assembly;
            string[] resources = thisAssembly.GetManifestResourceNames();
            int lcid = language?.Lcid ?? int.MinValue;
            string dropAllConstraintsText = dropAllConstraints ? "1" : "0";
            string setSingleUserText = setSingleUser && !auditOnly ? "1" : "0";

            object[] formatArgs = {database, collation, dropAllConstraintsText, lcid, setSingleUserText};

            //first get a list or resources
            ArrayList resourceNames = new ArrayList();
            foreach (string resource in resources)
            {
                if (string.Compare(resource.Substring(resource.Length - 4),
                        ".sql",
                        true,
                        CultureInfo.InvariantCulture) == 0)
                {
                    //we want this script...
                    //lets see if it is specific to a version of sql server
                    string versionText = resource.Substring(resource.Length - 9, 5);

                    // If auditOnly, include only "Setup", "Audit" and finalization (99*) steps
                    if (auditOnly && !resource.Contains("Setup") && !resource.Contains("Audit") &&
                        !resource.Contains("Scripts.99"))
                        continue;

                    if (versionText == ".2000")
                    {
                        if (serverVersion.Major <= 8)
                            resourceNames.Add(resource);
                    }
                    else if (versionText == ".2005")
                    {
                        if (serverVersion.Major >= 9)
                            resourceNames.Add(resource);
                    }
                    else
                    {
                        resourceNames.Add(resource);
                    }
                }
            }

            resourceNames.Sort();
            foreach (string resource in resourceNames)
            {
                script.Add(new ScriptStepResource(resource, formatArgs));
            }

            return script;
        }
    }
}